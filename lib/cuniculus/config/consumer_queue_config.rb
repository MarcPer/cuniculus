# frozen_string_literal: true

module Cuniculus
  module Config
    class ConsumerQueueConfig
      attr_reader :name
      def initialize(name)
        @name = name
      end

      def validate!
        raise ArgumentError if name.nil? || name.empty?
      end
    end
  end
end

