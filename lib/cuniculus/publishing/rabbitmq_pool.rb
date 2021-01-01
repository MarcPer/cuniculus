# frozen_string_literal: true

require 'bunny'
require 'connection_pool'

module Cuniculus
  module Publishing
    class RabbitmqPool
      CUNICULUS_EXCHANGE = 'cuniculus'
      ENFORCED_CONN_OPTS = {
        threaded: false # No need for a reader thread, since this connection is only used for publishing
      }.freeze

      class << self
        def init!(config)
          @conn = ::Bunny.new(config.rabbitmq_opts.merge(ENFORCED_CONN_OPTS))
          @conn.start
          @channel_pool = ConnectionPool.new(timeout: 1, size: config.pool_size) do
            ch = @conn.create_channel
            ch.direct(CUNICULUS_EXCHANGE, { durable: true })
            ch
          end
        end

        def with_exchange(&block)
          @channel_pool.with do |ch|
            block.call(ch.exchanges['cuniculus'])
          ensure
            ch.open if ch.closed?
          end
        end
      end
    end
  end
end

