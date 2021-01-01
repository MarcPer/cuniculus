# frozen_string_literal: true

require 'bunny'

module Cuniculus
  module Publishing
    class Producer
      attr_reader :config

      def initialize(config)
        @config = config
      end

      def connection
        @connection ||= Bunny.new(config.rabbitmq_opts)
      end
    end
  end
end

