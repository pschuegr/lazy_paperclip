module Paperclip
  class Null < Stylist

    def initialize src_path, options = {}, attachment = nil
      @src_path = src_path
    end

    def make
      File.open(@src_path, "rb")
    end
  end
end
