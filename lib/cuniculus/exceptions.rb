# frozen_string_literal: true

module Cuniculus
  # Cuniculus-specific exceptions
  #
  # * `Cuniculus::Error`: Default exception raised by Cuniculus.
  #   All exceptions classes defined by Cuniculus descend from this class.
  # * `Cuniculus::RMQConnectionError`: Raised when unable to connect to RabbitMQ.
  # * `Cuniculus::RMQQueueConfigurationConflict`: Raised when the queue configuration
  #   given to Cuniculus conflicts with the current configuration of the same
  #   existing queue in RabbitMQ.
  # * `Cuniculus::BadlyFormattedPayload`: Raised when Cuniculus consumer receives an
  #   improperly formatted job message.

  class Error < ::StandardError
    # If the Cuniculus exception wraps an underlying exception, the latter
    # is held here.
    attr_accessor :wrapped_exception

    # Underlying exception `cause`
    #
    # @return [Exception#cause]
    def cause
      wrapped_exception || super
    end
  end

  (
    ConfigError = Class.new(Error)
  ).name

  (
    RMQConnectionError = Class.new(Error)
  ).name

  (
    RMQQueueConfigurationConflict = Class.new(Error)
  ).name

  (
    BadlyFormattedPayload = Class.new(Error)
  ).name
end
