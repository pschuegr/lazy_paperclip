module Paperclip
  class Configuration

    DEFAULT_STYLISTS_PATH = 'lib/paperclip_stylists'

    attr_writer   :root, :env
    attr_accessor :use_dm_validations

    def root
      @root ||= Rails.root 
    end

    def root=(path)
      @root = File.expand_path(path)
    end

    def stylists_path
      @stylists_path ||= File.expand_path(DEFAULT_STYLISTS_PATH, root)
    end

    def stylists_path=(path)
      @stylists_path = File.expand_path(path, root)
    end
  end
end
