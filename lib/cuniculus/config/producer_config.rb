# frozen_string_literal: true

require_relative 'base_config'

module Cuniculus
  module Config
    class ProducerConfig < BaseConfig
      attr_accessor :pool_size

      PRODUCER_MERGED_IVARS = %w[rabbitmq_opts]
      def merge!(other_cfg)
        super
        PRODUCER_MERGED_IVARS.each do |ivar|
          x = :"@#{ivar}"
          self.instance_variable_set(x, other_cfg.instance_variable_get(x))
        end
      end

      def validate!

      end
    end
  end
end

