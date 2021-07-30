# frozen_string_literal: true

require "cuniculus/core"
require "cuniculus/exceptions"

module Cuniculus
  module Worker
    DEFAULT_OPTS = { queue: "cun_default" }.freeze
    VALID_OPT_KEYS = %i[queue].freeze

    def self.extended(base)
      base.instance_variable_set(:@cun_opts, DEFAULT_OPTS)
      super
    end

    def inherited(mod)
      mod.instance_variable_set(:@cun_opts, @cun_opts)
      super
    end

    attr_reader :cun_opts

    # Worker-specific options for running cuniculus.
    #
    # Note that options set on a worker class are inherited by its subclasses.
    #
    # @param opts [Hash]
    # @option opts [String] "queue" ("cun_default") Name of the underlying RabbitMQ queue.
    #
    # @example Change the queue name of a worker
    #   class MyWorker
    #     extend Cuniculus::Worker
    #
    #     cuniculus_options queue: "critical"
    #
    #     def perform
    #       # run the task
    #     end
    #   end
    def cuniculus_options(opts)
      opts = validate_opts!(opts)
      @cun_opts = opts
    end

    def validate_opts!(opts)
      raise Cuniculus::WorkerOptionsError, "Argument passed to 'cuniculus_options' should be a Hash" unless opts.is_a?(Hash)
      invalid_keys = opts.keys - VALID_OPT_KEYS
      raise Cuniculus::WorkerOptionsError, "Invalid keys passed to 'cuniculus_options': #{invalid_keys.inspect}" unless invalid_keys.empty?
      opts
    end

    def perform_async(*args)
      publish({ "class" => self, "args" => args })
    end

    def publish(item)
      routing_key = cun_opts[:queue]
      payload = normalize_item(item)
      Cuniculus.enqueue [Cuniculus::CUNICULUS_EXCHANGE, payload, routing_key]
    end

    def normalize_item(item)
      Cuniculus.dump_job(item)
    end
  end
end
