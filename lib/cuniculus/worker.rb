# frozen_string_literal: true

require "cuniculus/publishing/rabbitmq_pool"
require "json"

module Cuniculus
  module Worker
    CUNICULUS_EXCHANGE = Cuniculus::Publishing::RabbitmqPool::CUNICULUS_EXCHANGE

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def perform_async(*args)
        publish({ 'class' => self, 'args' => args })
      end

      def publish(item)
        routing_key = 'default'
        payload = normalize_item(item)
        Cuniculus::Publishing::RabbitmqPool.with_exchange do |x|
          puts "Publishing: #{x.inspect}"
          x.publish(payload, { routing_key: routing_key, persistent: true })
        end
      end

      def normalize_item(item)
        JSON.dump(item)
      end
    end
  end
end

