module Paperclip
  module Jobs
    class DelayedPaperclipJob < Struct.new(:instance_klass, :instance_id, :attachment_name)
      def perform
        process_job do
          instance.send(attachment_name).process!
        end
      end

      private
      def instance
        @instance ||= instance_klass.constantize.get(instance_id)
      end

      def process_job
        yield
      end
    end
  end
end
