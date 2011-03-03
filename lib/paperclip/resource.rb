require 'paperclip/attachment'

module Paperclip
  module FieldAccessorMethods
    def self.included(base)
      Resource::ATTRIBUTES.each do |a_name, a_data|
        if a_name != :status
          base.send(:define_method, "#{a_name.to_s}") do
            instance_read(a_name)
          end

          base.send(:define_method, "#{a_name.to_s}=") do |val|
            instance_write(a_name, val)
          end
        end
      end
    end
  end

  module Resource
    ATTRIBUTES = {
      :file_size    => {:type => String, :options => {:length => 255}},
      :content_type => {:type => String},
      :updated_at   => {:type => DateTime},
      :status       => {:type => Integer, :options => {:default => Attachment::INVALID}}
    }

    def self.included(base)
      base.extend ClassMethods
      Attachment.send(:include, FieldAccessorMethods)

      # Done at this time to ensure that the user
      # had a chance to configure the app in an initializer
      if Paperclip.config.use_dm_validations
        require 'dm-validations'
        require 'paperclip/validate'
        base.extend Paperclip::Validate::ClassMethods
      end

      Paperclip.require_stylists

    end
  end
end


