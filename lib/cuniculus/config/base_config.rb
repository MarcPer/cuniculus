# frozen_string_literal: true

module Cuniculus
  module Config
    class BaseConfig
      attr_accessor :exchange_name, :rabbitmq_opts

      def initialize
        @rabbitmq_opts = {
          host: '127.0.0.1',
          port: 5672,
          user: 'guest',
          pass: 'guest',
          vhost: '/',
        }
        @exchange_name = "cuniculus"
      end

      def self.default
        new
      end

      MERGED_IVARS = %w[exchange_name rabbitmq_opts]
      def merge!(other_cfg)
        MERGED_IVARS.each do |ivar|
          x = :"@#{ivar}"
          self.instance_variable_set(x, other_cfg.instance_variable_get(x))
        end
      end

      def validate!

      end
    end
  end
end

