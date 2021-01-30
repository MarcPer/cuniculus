# frozen_string_literal: true

require "bunny"
require "connection_pool"
require "cuniculus/core"
require "cuniculus/config"

module Cuniculus
  class RMQPool
    ENFORCED_CONN_OPTS = {
      threaded: false # No need for a reader thread, since this connection is only used for publishing
    }.freeze

    class << self
      def configure(config)
        @config = config
      end

      def config
        @config ||= Cuniculus::Config.new
      end

      def init!
        @conn = ::Bunny.new(@config.rabbitmq_opts.merge(ENFORCED_CONN_OPTS))
        @conn.start
        @channel_pool = ConnectionPool.new(timeout: 1, size: @config.pub_thr_pool_size) do
          ch = @conn.create_channel
          ch.direct(Cuniculus::CUNICULUS_EXCHANGE, { durable: true })
          ch.fanout(Cuniculus::CUNICULUS_DLX_EXCHANGE, { durable: true })
          ch
        end
      end

      def with_exchange(&block)
        init! unless @channel_pool
        @channel_pool.with do |ch|
          block.call(ch.exchanges["cuniculus"])
        ensure
          ch.open if ch.closed?
        end
      end
    end
  end
end
