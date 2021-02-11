# frozen_string_literal: true

require "cuniculus/core"
require "cuniculus/queue_config"

module Cuniculus
  class Config
    ENFORCED_CONN_OPTS = {
      threaded: false # No need for a reader thread, since this connection is only used for publishing
    }.freeze

    attr_accessor :dead_queue_ttl, :exchange_name, :pub_thr_pool_size, :rabbitmq_opts
    attr_reader :queues, :opts

    def initialize
      @opts = {}
      @queues = { "default" => QueueConfig.new({ "name" => "default" }) }
      @rabbitmq_opts = {
        host: "127.0.0.1",
        port: 5672,
        user: "guest",
        pass: "guest",
        vhost: "/"
      }
      @exchange_name = "cuniculus"
      @dead_queue_ttl = 1000 * 60 * 60 * 24 * 180 # 180 days
    end

    def declare!
      conn = ::Bunny.new(rabbitmq_opts.merge(ENFORCED_CONN_OPTS))
      conn.start
      ch = conn.create_channel
      declare_exchanges!(ch)
      declare_dead_queue!(ch)
      @queues.each_value { |q| q.declare!(ch) }
    end

    def default_queue=(bool)
      @queues.delete("default") unless bool
    end

    private

    def declare_exchanges!(ch)
      ch.direct(Cuniculus::CUNICULUS_EXCHANGE, { durable: true })
      ch.fanout(Cuniculus::CUNICULUS_DLX_EXCHANGE, { durable: true })
    end

    def declare_dead_queue!(ch)
      ch.queue(
        "cun_dead",
        durable: true,
        exclusive: false,
        arguments: {
          "x-message-ttl" => dead_queue_ttl
        }
      ).
        bind(Cuniculus::CUNICULUS_DLX_EXCHANGE)
    end
  end
end
