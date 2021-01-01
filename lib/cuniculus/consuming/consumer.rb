# frozen_string_literal: true

require "json"
require "thread"
require "cuniculus/logger"
require "cuniculus/publishing/rabbitmq_pool"

module Cuniculus
  module Consuming
    class Consumer
      CUNICULUS_EXCHANGE = Cuniculus::Publishing::RabbitmqPool::CUNICULUS_EXCHANGE
      attr_reader :channel, :queue

      def initialize(supervisor, queue_name, channel)
        @supervisor = supervisor
        @channel = channel
        x = channel.direct(CUNICULUS_EXCHANGE, { durable: true })
        @queue = channel.queue(queue_name, durable: true, exclusive: false)
        @queue.bind(x, { routing_key: 'default' })
        @done_queue = ::Queue.new
        @thread = nil
      end

      def start
        @thread = ::Thread.new do
          queue.subscribe(manual_ack: true, block: false) do |delivery_info, properties, payload|
            run_job(delivery_info, payload)
          end
          @done_queue.pop
        end
      end

      def stop
        @done_queue << :terminate
      end

      def run_job(delivery_info, payload)
        item = ::JSON.load(payload)
        klass = constantize(item['class'])
        worker = klass.new
        worker.perform(*item['args'])
        channel.ack(delivery_info.delivery_tag, false)
      rescue Exception => ex
        Cuniculus.logger.error(ex)
        @supervisor.consumer_exception(self, ex)
      end

      def constantize(str)
        return Object.const_get(str) unless str.include?("::")

        names = str.split("::")
        names.shift if names.empty? || names.first.empty?

        names.inject(Object) do |constant, name|
          constant.const_get(name, false)
        end
      end
    end
  end
end

