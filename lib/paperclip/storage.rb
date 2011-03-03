module Paperclip
  module Storage
    module Base
      def save_local_file(path, src)
        FileUtils.mkdir_p(File.dirname(path))

        src_io =  case src
                  when File then src
                  when Tempfile then src
                  when String then File.new(path, "rb")
                  else raise "Unknown source"
                  end

        if src_io.path != path
          dst_file = File.new(path, "wb")
          save_to(dst_file, src_io)
        end
      end

      def save_to dst_io, src_io, in_blocks_of = 8192
        buffer = ""
        src_io.rewind
        while src_io.read(in_blocks_of, buffer) do
          dst_io.write(buffer)
        end
        dst_io.rewind    
        dst_io
      end

      def local_file(path)
        File.open(path, "rb")
      end

      def local_file_exists?(path)
        File.exist?(path) || File.directory?(path)
      end

      def delete_local_file(path)
        if File.directory? path
          FileUtils.rm_rf(path)
        elsif File.exist? path
          FileUtils.rm(path)
        end
      end

      def process_file style
        local_file(process_file_path(style))
      end

      def process_file_path style
        path = File.join(Dir.tmpdir, path(style))
      end

      def log message #:nodoc:
        Paperclip.log(message)
      end
    end
  end
end
