# frozen_string_literal: true

require "cuniculus/core"
require "cuniculus/exceptions"
require "cuniculus/job_queue"

module Cuniculus
  class QueueConfig
    OPTS = {}.freeze

    DEFAULT_MAX_RETRY = 4

    attr_reader :max_retry, :name, :thread_pool_size

    def initialize(opts = OPTS)
      @name = read_opt(opts, "name") || "cun_default"
      @max_retry = read_opt(opts, "max_retry") || DEFAULT_MAX_RETRY
      @thread_pool_size = read_opt(opts, "thread_pool_size")
    end

    def read_opt(opts, key)
      opts[key.to_s] || opts[key.to_sym]
    end

    def declare!(channel)
      queue_name = name
      base_q = channel.queue(
        queue_name,
        durable: true,
        exclusive: false,
        arguments: { "x-dead-letter-exchange" => Cuniculus::CUNICULUS_DLX_EXCHANGE }
      )
      base_q.bind(Cuniculus::CUNICULUS_EXCHANGE, { routing_key: name })

      retry_queue_names = (1..max_retry).map { |i| "#{name}_#{i}" }
      max_retry.times do |i|
        queue_name = retry_queue_names[i]

        q = channel.queue(
          queue_name,
          durable: true,
          exclusive: false,
          arguments: {
            "x-dead-letter-exchange" => Cuniculus::CUNICULUS_EXCHANGE,
            "x-dead-letter-routing-key" => name,
            "x-message-ttl" => ((i**4) + (15 * (i + 1))) * 1000
          }
        )
        q.bind(Cuniculus::CUNICULUS_EXCHANGE, { routing_key: queue_name })
      end

      Cuniculus::JobQueue.new(base_q, retry_queue_names)
    rescue Bunny::PreconditionFailed => e
      raise Cuniculus.convert_exception_class(e, Cuniculus::RMQQueueConfigurationConflict), "Declaration failed for queue '#{queue_name}'"
    end
  end
end
