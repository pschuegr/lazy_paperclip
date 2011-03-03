module Paperclip

  class Stylist
    attr_accessor :src, :options, :attachment

    def initialize src, options = {}, attachment = nil
      @src = src
      @src_path = src.path
      @options = options
      @attachment = attachment
    end

    def make
    end

    def self.make src, options = {}, attachment = nil
      new(src, options, attachment).make
    end

    def log string
      Paperclip.log string
    end

    def file_convert(transcoder_command, params, src_path, src_encoding, dst_path, dst_encoding)
      params.gsub! ":src_path", src_path if !src_path.nil?
      params.gsub! ":src_encoding", src_encoding.to_s if !src_encoding.nil?
      params.gsub! ":dst_path", dst_path if !dst_path.nil?
      params.gsub! ":dst_encoding", dst_encoding.to_s if !dst_encoding.nil?

      Paperclip.run_command transcoder_command, params
    end    

    def file_encoding(filename, valid_encodings)
      file_info = Paperclip.run_command("file", "\"#{@src_path}\"").strip
      valid_encodings.keys.each do |encoding|
        return encoding if file_info.match valid_encodings[encoding][:regex]
      end

      :unknown
    end
  end
end
