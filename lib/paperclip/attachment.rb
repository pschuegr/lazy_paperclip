require_dependency 'paperclip/storage/s3'
require_dependency 'paperclip/storage/filesystem'

module Paperclip

  # The Attachment class manages the files for a given attachment. It saves
  # when the model saves, deletes when the model is destroyed, and processes
  # the file upon assignment.
  class Attachment

    INVALID = 0
    UPLOADED = 1
    STYLING = 2
    STYLED = 3
    STORED = 4

    IMAGE_ENCODINGS = { 
      :jpg => {:ext => :jpg, :regex => "JPEG"}, 
      :png => {:ext => :png, :regex => "PNG"},
      :gif => {:ext => :gif, :regex => "GIF"}}

    AUDIO_ENCODINGS = { 
      :mp3 => {:ext => :mp3, :regex => "MPEG.*layer.*III"}, 
      :vorbis => {:ext => :ogg, :regex => "Vorbis"},
      :flac => {:ext => :flac, :regex => "FLAC"}}

    def self.extension(encoding)
      all_encodings = IMAGE_ENCODINGS.merge(AUDIO_ENCODINGS)
      (encoding && all_encodings.keys.include?(encoding)) ? all_encodings[encoding][:ext] : :bin
    end

    def self.default_options
      @default_options ||= {
        :root             => "#{Paperclip.config.root}/public",
        :path             => ->(instance, options) { "/#{instance.class.to_s}/:attachment/:style.:ext"},
        :processing_url   => ->(instance, options) { "/#{instance.class.to_s}/:attachment/:style.:ext"},
        :storage          => :filesystem,
        :styles           => { :original => { :stylists => [:null]}},
        :default_style    => nil,
        :validations      => [],
        :whiny            => Paperclip.options[:whiny] 
      }
    end

    attr_reader :name, :instance, :styles, :default_style, :options

    # Creates an Attachment object. +name+ is the name of the attachment,
    # +instance+ is the ActiveRecord object instance it's attached to, and
    # +options+ is the same as the hash passed to +has_attached_file+.
    def initialize name, instance, options = {}
      @name               = name
      @instance           = instance
      @options            = self.class.default_options.merge(options)

      @root               = @options[:root]
      @path               = @options[:path]
      @processing_url     = @options[:processing_url]
      @storage            = @options[:storage]
      @styles             = @options[:styles] || {}
      @default_style      = @options[:default_style] || @styles.keys.first
      @validations        = @options[:validations]
      @whiny              = @options[:whiny]

      @errors             = {}
      @validation_errors  = nil
      @dirty              = false

      initialize_storage
    end

    # What gets called when you call instance.attachment = File. It clears
    # errors, assigns attributes, processes the file, and runs validations. It
    # also queues up the previous file for deletion, to be flushed away on
    # #save of its host.  In addition to form uploads, you can also assign
    # another Paperclip attachment:
    #   new_user.avatar = old_user.avatar
    # If the file that is assigned is not valid, the processing (i.e.
    # thumbnailing, etc) will NOT be run.
    def assign uploaded_file
      log("assigning file: " + uploaded_file.inspect)
      raise if uploaded_file.nil?
      raise unless valid_assignment?(uploaded_file)

      self.clear

      queue_for_write({:upload => uploaded_file.tempfile})

      self.content_type  = uploaded_file.tempfile.content_type.to_s.strip
      self.file_size     = uploaded_file.tempfile.size.to_i
      self.updated_at    = Time.now
      self.status        = UPLOADED

      @dirty = true
    end

    # This method really shouldn't be called that often. It's expected use is
    # in the paperclip:refresh rake task and that's it. It will regenerate all
    # thumbnails forcefully, by reobtaining the original file and going through
    # the post-process again.
    def process!
      solidify
      style_uploaded_file
      store_styled_files
      @instance.save
    end

    def solidify
      solidify_style_definitions
    end

    def style_uploaded_file
      if status == UPLOADED
        log("Styling uploaded file: #{process_file_path(:upload)}")
        begin
          self.status = STYLING

          make_styles

          flush_writes
          flush_deletes
 
          self.status = STYLED

          true
        rescue => e
          log(e.message)
          log(e.backtrace)
          self.status = UPLOADED

          raise e
        end
      end
    end

    def store_styled_files
      if status == STYLED
        begin
          @styles.each do |name, args|
            queue_for_write({name => process_file(name)})
          end

          queue_for_delete({ :dir => nil })

          flush_writes #do this first so that it will fail before deleting the files
          flush_deletes

          self.status = STORED

          true 
        rescue => e
          log(e.message)
          log(e.backtrace)
          self.status = STYLED

          raise e
        end
      end
    end

    def status
      instance_read(:status) || INVALID
    end

    def status= status
      instance_write(:status, status)
    end

    def ready?
      status == STORED
    end

    def uploaded?
      status != INVALID
    end

    # Returns the public URL of the attachment, with a given style. Note that
    # this does not necessarily need to point to a file that your web server
    # can access and can point to an action in your app, if you need fine
    # grained security.  This is not recommended if you don't need the
    # security, however, for performance reasons.  set
    # include_updated_timestamp to false if you want to stop the attachment
    # update time appended to the url
    def url style = default_style, include_updated_timestamp = true
      url = ready? ? root + '/' + path(style) : processing_url(style)
      include_updated_timestamp && updated_at ? [url, updated_at.to_i].compact.join(url.include?("?") ? "&" : "?") : url
    end

    # Returns the path of the attachment as defined by the :path option. If the
    # file is stored in the filesystem the path refers to the path of the file
    # on disk. If the file is stored in S3, the path is the "key" part of the
    # URL, and the :bucket option refers to the S3 bucket.
    def path style = default_style
      path = do_substitutions @path.call(@instance), style
      style != :dir ? path : File.dirname(path)
    end

    def processing_url style = default_style
      do_substitutions @processing_url.call(@instance), style
    end
    
    def do_substitutions(string, style)
      string.gsub! ":style", style.to_s
      string.gsub! ":ext", extension(style).to_s
      string.gsub! ":attachment", name.to_s 
      string.gsub! ":id", @instance.id.to_s

      string
    end

    def root
      @root
    end

    def extension style = default_style
      if styles[style] 
        encoding = styles[style][:encoding]
        Paperclip::Attachment.extension(encoding)
      else
        style.to_s
      end
    end

    # Alias to +url+
    def to_s style = default_style
      url(style)
    end

    # Returns true if there are no errors on this attachment.
    def valid?
      validate
      errors.empty?
    end

    # Returns an array containing the errors on this attachment.
    def errors
      @errors
    end

    # Returns true if there are changes that need to be saved.
    def dirty?
      @dirty
    end

    # Saves the file, if there are no errors. If there are, it flushes them to
    # the instance's errors and returns false, cancelling the save.
    def save
      if valid?
        flush_deletes 
        flush_writes
        @dirty = false

        enqueue_process_job if status == UPLOADED

        true
      else
        flush_errors
        false
      end
    end

    def enqueue_process_job
      if defined? Delayed::Worker
        Delayed::Job.enqueue Paperclip::Jobs::DelayedPaperclipJob.new(@instance.class.name, @instance.id, name.to_sym)
      else
        raise "No job system"
      end
    end

    # Clears out the attachment. Has the same effect as previously assigning
    # nil to the attachment. Does NOT save. If you wish to clear AND save,
    # use #destroy.
    def clear
      queue_files_for_delete

      Paperclip::Resource::ATTRIBUTES.each do |a_name, a_data|
        instance_write(a_name, nil)
      end

      instance_write(:status, INVALID)

      @errors            = {}
      @validation_errors = nil
    end

    # Destroys the attachment. Has the same effect as previously assigning
    # nil to the attachment *and saving*. This is permanent. If you wish to
    # wipe out the existing attachment but not save, use #clear.
    def destroy
      clear
      save
    end

    # Returns true if a file has been assigned.
    def file?
      status != INVALID  
    end

    # Writes the attachment-specific attribute on the instance. For example,
    # instance_write(:file_name, "me.jpg") will write "me.jpg" to the instance's
    # "avatar_file_name" field (assuming the attachment is called avatar).
    def instance_write(attr, value)
      setter = :"#{name}_#{attr}="
      raise unless @instance.respond_to?(setter)
      @instance.send(setter, value)
    end

    # Reads the attachment-specific attribute on the instance. See instance_write
    # for more details.
    def instance_read(attr)
      getter = :"#{name}_#{attr}"
      raise unless @instance.respond_to?(getter)
      @instance.send(getter)
    end

    private

    def initialize_storage #:nodoc:
      @storage_module = Storage.const_get(@storage.to_s.capitalize)
      self.extend(@storage_module)
    end

    def solidify_style_definitions #:nodoc:
      @styles.each do |name, args|
        @styles[name][:stylists] = @styles[name][:stylists].call(instance) if @styles[name][:stylists].respond_to?(:call)
      end
    end

    def make_styles #:nodoc:
      @styles.each do |name, args|
        begin
          raise RuntimeError.new("Style #{name} has no stylists defined.") if args[:stylists].blank?
          #log("Creating #{name} style")

          styling_result = args[:stylists].inject(process_file(:upload)) do |file, stylist|
            Paperclip.stylist(stylist).make(file, args, self)
          end

          queue_for_write({name => styling_result})
          #log("Created with size #{File.size(styling_result).to_s}")
        rescue PaperclipError => e
          log("An error was received while processing: #{e.inspect}")
          (@errors[:styling] ||= []) << e.message if @whiny
        end
      end
    end

    def queue_files_for_delete #:nodoc:
      @styles.keys.push(:upload).each do |style|
        queue_for_delete({ style => nil })
      end
    end

    def flush_errors #:nodoc:
      @errors.each do |error, message|
        [message].flatten.each {|m| instance.errors.add(name, m) }
      end
    end

    def log message #:nodoc:
      Paperclip.log(message)
    end

    def valid_assignment? file #:nodoc:
      if file.is_a?(Hash) 
        file[:filename] || file['filename']
      else
        file.nil? || (file.respond_to?(:original_filename) && file.respond_to?(:content_type))
      end
    end

    def validate #:nodoc:
      unless @validation_errors
        @validation_errors = @validations.inject({}) do |errors, validation|
          name, options = validation
          errors[name] = send(:"validate_#{name}", options) if allow_validation?(options)
          errors
        end
        @validation_errors.reject!{|k,v| v == nil }
        @errors.merge!(@validation_errors)
      end
      @validation_errors
    end

    def allow_validation? options #:nodoc:
      (options[:if].nil? || check_guard(options[:if])) && (options[:unless].nil? || !check_guard(options[:unless]))
    end

    def check_guard guard #:nodoc:
      if guard.respond_to? :call
        guard.call(instance)
      elsif ! guard.blank?
        instance.send(guard.to_s)
      end
    end

    def validate_size options #:nodoc:
      if file? && !options[:range].include?(size.to_i)
        options[:message].gsub(/:min/, options[:min].to_s).gsub(/:max/, options[:max].to_s)
      end
    end

    def validate_presence options #:nodoc:
      options[:message] unless file?
    end

    def validate_content_type options #:nodoc:
      valid_types = [options[:content_type]].flatten
      unless !file?
        unless valid_types.blank?
          content_type = instance_read(:content_type)
          unless valid_types.any?{|t| content_type.nil? || t === content_type }
            options[:message] || "is not one of the allowed file types."
          end
        end
      end
    end
  end
end
