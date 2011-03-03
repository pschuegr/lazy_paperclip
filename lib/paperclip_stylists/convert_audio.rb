module Paperclip
  class ConvertAudio < Stylist

    def make
      @src_encoding     = file_encoding(@src_path, Paperclip::Attachment::AUDIO_ENCODINGS)
      @dst_encoding     = options[:encoding]
      @dir              = File.dirname(@src_path)
      @basename         = File.basename(@src_path, File.extname(@src_path))
      @dst_path         = File.join(@dir, "#{@basename}.#{Paperclip::Attachment::AUDIO_ENCODINGS[@dst_encoding][:ext]}")
			@instance 				= attachment.instance

      if @src_encoding != :unknown 
        begin
          file_convert("sox", "-t \":src_encoding\" \":src_path\" -t \":dst_encoding\" \":dst_path\"", @src_path, @src_encoding, @dst_path, @dst_encoding)
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
