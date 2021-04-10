# frozen_string_literal: true

require "cuniculus/core"
require "cuniculus/exceptions"
require "cuniculus/queue_config"

module Cuniculus
  class Config
    ENFORCED_CONN_OPTS = {
      threaded: false, # No need for a reader thread, since this connection is only used for declaring exchanges and queues.
      automatically_recover: false,
      log_level: Logger::ERROR
    }.freeze

    attr_accessor(
      :dead_queue_ttl,
      :exchange_name,
      :pub_pool_size,
      :pub_reconnect_attempts,
      :pub_reconnect_delay,
      :pub_reconnect_delay_max,
      :pub_shutdown_grace_period,
      :rabbitmq_opts
    )

    attr_reader :queues, :opts

    def initialize
      @opts = {}

      # ---- Default values
      @queues = { "cun_default" => QueueConfig.new({ "name" => "cun_default" }) }
      @rabbitmq_opts = {
        host: "127.0.0.1",
        port: 5672,
        user: "guest",
        pass: "guest",
        vhost: "/"
      }
      @exchange_name = Cuniculus::CUNICULUS_EXCHANGE
      @dead_queue_ttl = 1000 * 60 * 60 * 24 * 180 # 180 days
      @pub_reconnect_attempts = :infinite
      @pub_reconnect_delay = 1.5
      @pub_reconnect_delay_max = 10
      @pub_shutdown_grace_period = 50
      @pub_pool_size = 5
      ## ---- End of default values
    end

    # Configure an additional queue
    #
    # Note that a single call to `add_queue` might lead to the creation of multiple queues on RabbitMQ: one base queue, and an additional queue for every retry attempt.
    # For example, with a queue named `"test"` with `max_retry` set to `4`, 5 queues are created in RabbitMQ.
    #
    # For tuning `prefetch_count`, refer to [this guide](https://www.cloudamqp.com/blog/2017-12-29-part1-rabbitmq-best-practice.html#prefetch).
    #
    # If a queue already exists in RabbitMQ, and an attempt is done to add it again through `add_queue`, nothing happens, except if the options passed to `add_queue` conflict with the existing queue. For example if a queue exists that is durable, and `add_queue` is called with `"durable" => false`, a `Cuniculus::RMQQueueConfigurationConflict` is raised. To redeclare a queue with conflicting configurations, the original queue has first to be removed from RabbitMQ manually. This can be done, for example, through the management console.
    #
    # @param qopts [Hash] Queue config options.
    # @option qopts [String] "name" Name of the queue.
    # @option qopts [Boolean] "durable" (true) Whether queue is declared as durable in RabbitMQ. Jobs in non-durable queues may be lost if the RabbitMQ goes down.
    # @option qopts [Integer] "max_retry" (8) Number of retries for failed jobs in this queue.
    # @option qopts [Integer] "prefetch_count" (10) Prefetch count used when consuming jobs from this queue.
    # @option qopts [Integer] "thread_pool_size" (5) Thread pool size for receiving jobs.
    #
    # @example Add queue named "critical"
    #   Cuniculus.configure do |cfg|
    #     cfg.add_queue({ name: "critical", max_retry: 10 })
    #   end
    def add_queue(qopts)
      qopts = qopts.transform_keys(&:to_s)
      qname = qopts["name"].to_s
      raise Cuniculus::ConfigError, "Missing 'name' key in queue configuration hash" if qname.strip.empty?
      @queues[qname] = QueueConfig.new(qopts)
    end

    def declare!
      conn = ::Bunny.new(rabbitmq_opts.merge(ENFORCED_CONN_OPTS))
      conn.start
      ch = conn.create_channel
      declare_exchanges!(ch)
      declare_dead_queue!(ch)
      @queues.each_value { |q| q.declare!(ch) }
      conn.close unless conn.closed?
    rescue Bunny::TCPConnectionFailed => ex
      raise Cuniculus.convert_exception_class(ex, Cuniculus::RMQConnectionError)
    end

    # Specify if the default queue `cun_default` should be created.
    # `cun_default` is used by workers that don't explicitly specify a queue with `cuniculus_options queue: "another_queue"`.
    #
    # @param bool [Boolean] If false, queue `cun_default` is not created. Defaults to `true`.
    def default_queue=(bool)
      @queues.delete("cun_default") unless bool
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
      ).bind(Cuniculus::CUNICULUS_DLX_EXCHANGE)
    end
  end
end
