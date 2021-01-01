# frozen_string_literal: true

require "bunny"
require "cuniculus/consuming/consumer"

module Cuniculus
  class Supervisor
    attr_reader :config
    def initialize(config)
      @config = config
      @conn = ::Bunny.new(config.rabbitmq_opts)
      @conn.start
      @consumers = create_consumers
      @consumer_lock = Mutex.new
      @done = false
    end

    def start
      @consumers.each(&:start)
    end

    def stop
      @done = true
      @consumers.each(&:stop) 
    end

    def create_consumers
      consumers = [] 
      consumer_pool_size = 5
      config.queues.each do |name, _qcfg|
        ch = @conn.create_channel(nil, consumer_pool_size)
        consumers << Consuming::Consumer.new(self, name, ch)
      end
      consumers
    end

    def consumer_exception(consumer, ex)
      @consumer_lock.synchronize do
        @consumers.delete(consumer)
        unless @done
          # Reuse channel
          ch = consumer.channel
          name = consumer.queue.name
          c = Consuming::Consumer.new(self, name, ch)
          @consumers << c
          c.start
        end
      end
    end
  end
end

