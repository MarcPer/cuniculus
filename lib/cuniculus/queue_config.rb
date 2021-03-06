# frozen_string_literal: true

require "cuniculus/core"
require "cuniculus/exceptions"
require "cuniculus/job_queue"

module Cuniculus
  class QueueConfig
    DEFAULT_MAX_RETRY = 8
    DEFAULT_PREFETCH_COUNT = 10
    DEFAULT_QUEUE_NAME = "cun_default"
    DEFAULT_THREAD_POOL_SIZE = 5

    attr_reader :durable, :max_retry, :name, :prefetch_count, :thread_pool_size

    def initialize(opts = {})
      opts = opts.transform_keys(&:to_s)
      @durable = read_opt(opts["durable"], true)
      @name = read_opt(opts["name"], DEFAULT_QUEUE_NAME)
      @max_retry = read_opt(opts["max_retry"], DEFAULT_MAX_RETRY)
      @prefetch_count = read_opt(opts["prefetch_count"], DEFAULT_PREFETCH_COUNT)
      @thread_pool_size = read_opt(opts["thread_pool_size"], DEFAULT_THREAD_POOL_SIZE)
      freeze
    end

    def read_opt(val, default)
      val.nil? ? default : val
    end

    def declare!(channel)
      queue_name = name
      base_q = channel.queue(
        queue_name,
        durable: durable,
        exclusive: false,
        arguments: { "x-dead-letter-exchange" => Cuniculus::CUNICULUS_DLX_EXCHANGE }
      )
      base_q.bind(Cuniculus::CUNICULUS_EXCHANGE, { routing_key: name })

      retry_queue_names = (1..max_retry).map { |i| "#{name}_#{i}" }
      max_retry.times do |i|
        queue_name = retry_queue_names[i]

        q = channel.queue(
          queue_name,
          durable: durable,
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
