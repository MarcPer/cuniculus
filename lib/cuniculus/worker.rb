# frozen_string_literal: true

require "cuniculus/core"
require "cuniculus/rmq_pool"

module Cuniculus
  module Worker
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def perform_async(*args)
        publish({ "class" => self, "args" => args })
      end

      def publish(item)
        routing_key = "default"
        payload = normalize_item(item)
        Cuniculus::RMQPool.with_exchange do |x|
          x.publish(payload, { routing_key: routing_key, persistent: true })
        end
      end

      def normalize_item(item)
        Cuniculus.dump_job(item)
      end
    end
  end
end
