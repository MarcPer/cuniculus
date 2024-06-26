# frozen_string_literal: true

require "bunny"

require "cuniculus/core"
require "cuniculus/exceptions"
require "cuniculus/consumer"

module Cuniculus
  module SupervisorMethods
    attr_reader :config

    def initialize(config)
      @config = config
      conn = connect(config.rabbitmq_opts)
      @consumers = create_consumers(conn, config.queues)
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

    def connect(conn_opts)
      conn = ::Bunny.new(conn_opts)
      conn.start
      conn
    rescue StandardError => e
      raise Cuniculus.convert_exception_class(e, Cuniculus::RMQConnectionError)
    end

    def create_consumers(conn, queues)
      consumers = []
      queues.each_value do |q_cfg|
        ch = conn.create_channel(nil, q_cfg.thread_pool_size)
        ch.prefetch(q_cfg.prefetch_count) if q_cfg.prefetch_count
        consumers << Cuniculus::Consumer.new(q_cfg, ch)
      end
      consumers
    end

    def consumer_exception(consumer, _ex)
      @consumer_lock.synchronize do
        @consumers.delete(consumer)
        unless @done
          # Reuse channel
          ch = consumer.channel
          name = consumer.queue.name
          c = Cuniculus::Consumer.new(self, name, ch)
          @consumers << c
          c.start
        end
      end
    end
  end

  class Supervisor
    include SupervisorMethods
  end
end

