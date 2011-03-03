require_dependency 'paperclip/storage'

module Paperclip
  module Storage
    # The default place to store attachments is in the filesystem. Files on
    # the local filesystem can be very easily served by Apache without
    # requiring a hit to your app. They also can be processed more easily
    # after they've been saved, as they're just normal files. There is one
    # Filesystem-specific option for has_attached_file.
    # * +path+: The location of the repository of attachments on disk. This
    #   can (and, in almost all cases, should) be coordinated with the
    #   value of the +url+ option to allow files to be saved into a place
    #   where Apache can serve them without hitting your app. Defaults to:
    #     ":rails_root/public/:attachment/:id/:style/:basename.:extension"
    #   By default this places the files in the app's public directory
    #   which can be served directly. If you are using capistrano for
    #   deployment, a good idea would be to make a symlink to the
    #   capistrano-created system directory from inside your app's public
    #   directory. See Paperclip::Attachment#interpolate for more
    #   information on variable interpolaton.
    #     :path => "/var/app/attachments/:class/:id/:style/:basename.:extension"
    module Filesystem
      include Paperclip::Storage::Base

      def self.extended(base)
        base.instance_eval do
          @queued_for_delete = {}
          @queued_for_write  = {}
        end
      end

      def final_path(style)
        File.join(root, path(style))
      end

      def exists?(style = default_style)
        if file? 
          case status
          when Paperclip::Attachment::STORED then local_file_exists?(final_path(style))
          else local_file_exists?(process_file_path(style))
          end
        else
          false
        end
      end

      # Returns representation of the data of the file assigned to the given
      # style, in the format most representative of the current storage.
      def to_file(style = default_style)
        raise if status == Paperclip::Attachment::INVALID
        case status
        when Paperclip::Attachment::STORED then local_file(final_path(style))
        else local_file(process_file_path(style))
        end
      end

      def flush_writes #:nodoc:
        log('flushing writes: ' + @queued_for_write.inspect)
        @queued_for_write.each do |style, file|
          case status
          when Paperclip::Attachment::STYLED then save_local_file(final_path(style), file)
          else save_local_file(process_file_path(style), file)
          end
        end
        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        log('flushing deletes: ' + @queued_for_delete.inspect)
        @queued_for_delete.each do |style, path|
          case status
          when Paperclip::Attachment::STORED then delete_local_file(final_path(style))
          else delete_local_file(process_file_path(style))
          end
        end
        @queued_for_delete = {}
      end

      def queue_for_delete styles_and_files
        @queued_for_delete.merge!(styles_and_files)
      end

      def queue_for_write styles_and_files
        @queued_for_write.merge!(styles_and_files)
      end

      def queued_for_write
        @queued_for_write
      end

      def queued_for_delete
        @queued_for_delete
      end
    end
  end
end
