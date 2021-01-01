# frozen_string_literal: true

require_relative 'base_config'
require_relative 'consumer_queue_config'

module Cuniculus
  module Config
    class ConsumerConfig < BaseConfig
      attr_reader :queues

      def initialize
        super
        @queues = {}
        add_queue(name: 'default')
      end

      CONSUMER_MERGED_IVARS = %w[rabbitmq_opts]
      def merge!(other_cfg)
        super
        CONSUMER_MERGED_IVARS.each do |ivar|
          x = :"@#{ivar}"
          self.instance_variable_set(x, other_cfg.instance_variable_get(x))
        end
      end

      def validate!

      end

      def add_queue(name: qname)
        q = ConsumerQueueConfig.new(name)
        q.validate!
        @queues[q.name] = q
      end
    end
  end
end

