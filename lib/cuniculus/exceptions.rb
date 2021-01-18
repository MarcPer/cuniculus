# frozen_string_literal: true

module Cuniculus
  # Default exception raised by Cuniculus.
  # All exception classes defined by Cuniculus descend from this class.
  class Error < ::StandardError
    # If the Cuniculus exception wraps an underlying exception, the latter
    # is held here.
    attr_accessor :wrapped_exception

    def cause
      wrapped_exception || super
    end
  end

  (
    # Error raised when Cuniculus is unable to connect to RabbitMQ with
    # the parameters it was given.
    RMQConnectionError = Class.new(Error)
  ).name

  (
    # Error raised when the queue configuration given to Cuniculus conflicts
    # with the current configuration of the same existing queue in RabbitMQ.
    RMQQueueConfigurationConflict = Class.new(Error)
  ).name

  (
    # Error raised when Cuniculus is unable to connect to RabbitMQ with
    # the parameters it was given.
    BadlyFormattedJobMessage = Class.new(Error)
  ).name
end
