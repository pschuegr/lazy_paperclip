module Paperclip
  class ConvertImage < Stylist


    # Performs the conversion of the +file+ into a thumbnail. Returns the Tempfile
    # that contains the new image.
    def make
      @src_encoding     = file_encoding(@src_path, Paperclip::Attachment::IMAGE_ENCODINGS)
      @dst_encoding     = options[:encoding]
      @dir              = File.dirname(@src_path)
      @basename         = File.basename(@src_path, File.extname(@src_path))
      @dst_path         = File.join(@dir, "#{@basename}.#{Paperclip::Attachment::IMAGE_ENCODINGS[@dst_encoding][:ext]}")
			@instance 				= attachment.instance

      if @src_encoding != :unknown 
        begin
          params = "\":src_path\" -resize #{options[:size]} \":dst_path\""
          file_convert("convert", params, @src_path, nil, @dst_path, nil)
        rescue PaperclipCommandLineError
          error = "Error converting #{@src_path} to #{@dst_encoding.to_s}"
          raise PaperclipError, error if @whiny
          log error 
        end
      else
        log("Unknown source encoding error: #{@src_encoding}")
      end

      File.open(@dst_path, "rb")
    end
  end
end
