# frozen_string_literal: true

require "cuniculus/core"
require "cuniculus/rmq_pool"

module Cuniculus
  module Worker
    def self.included(base)
      base.extend(ClassMethods)

      # Dev note:
      # The point here is to allow options set via cuniculus_options to be
      # inherited by subclasses.
      # When reading the options, a subclass will call the singleton method cun_opts.
      # If the subclass doesn't redefine this method via a call to cuniculus_options,
      # it will still use the definition from its parent class.
      base.define_singleton_method("cun_opts=") do |opts|
        singleton_class.class_eval do
          define_method("cun_opts") { opts }
        end
      end
    end

    module ClassMethods
      DEFAULT_OPTS = { "queue" => "cun_default" }.freeze
      VALID_OPT_KEYS = %w[queue].freeze

      # Read-only cuniculus option values
      #
      # @return opts [Hash] hash with current values
      def cun_opts
        DEFAULT_OPTS
      end

      # Worker-specific options for running cuniculus.
      #
      # Note that options set on a worker class are inherited by its subclasses.
      #
      # @param opts [Hash]
      # @option opts [String] "queue" ("cun_default") Name of the underlying RabbitMQ queue.
      #
      # @example Change the queue name of a worker
      #   class MyWorker
      #     include Cuniculus::Worker
      #
      #     cuniculus_options queue: "critical"
      #
      #     def perform
      #       # run the task
      #     end
      #   end
      def cuniculus_options(opts)
        opts = validate_opts!(opts)
        self.cun_opts = opts
      end

      def validate_opts!(opts)
        raise WorkerOptionsError, "Argument passed to 'cuniculus_options' should be a Hash" unless opts.is_a?(Hash)
        opts = opts.transform_keys(&:to_s)
        invalid_keys = opts.keys - VALID_OPT_KEYS
        raise WorkerOptionsError, "Invalid keys passed to 'cuniculus_options': #{invalid_keys.inspect}" unless invalid_keys.empty?
        opts
      end

      def perform_async(*args)
        publish({ "class" => self, "args" => args })
      end

      def publish(item)
        routing_key = cun_opts["queue"]
        payload = normalize_item(item)
        Cuniculus::RMQPool.with_exchange do |x|
          x.publish(payload, { routing_key: routing_key, persistent: true })
        end
      end

      def normalize_item(item)
        Cuniculus.dump_job(item)
      end
    end
  end
end
