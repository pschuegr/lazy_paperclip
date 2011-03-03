module Paperclip
  # The UploadedFile module is a convenience module for adding uploaded-file-type methods
  # to the +File+ class. Useful for testing.
  #   user.avatar = File.new("test/test_avatar.jpg")
  module UploadedFile

    # Infer the MIME-type of the file from the extension.
    def content_type
      type = (self.path.match(/\.(\w+)$/)[1] rescue "octet-stream").downcase
      case type
      when %r"jpe?g"                 then "image/jpeg"
      when %r"tiff?"                 then "image/tiff"
      when %r"png", "gif", "bmp"     then "image/#{type}"
      when "txt"                     then "text/plain"
      when %r"html?"                 then "text/html"
			when %r"mp3", "flac", "ogg"		 then "audio/#{type}"
      when "csv", "xml", "css", "js" then "text/#{type}"
      else "application/x-#{type}"
      end
    end

    # Returns the file's normal name.
    def basename
      File.basename(self.path)
    end

    # Returns the size of the file.
    def size
      File.size(self)
    end
  end
end

if defined? StringIO
  class StringIO
    attr_accessor :filename, :content_type
    def filename
      @filename ||= "stringio.txt"
    end
    def content_type
      @content_type ||= "text/plain"
    end
  end
end

class File #:nodoc:
  include Paperclip::UploadedFile
end
