# frozen_string_literal: true

module Cuniculus
  # Cuniculus-specific exceptions
  #
  # * `Cuniculus::Error`: Default exception raised by Cuniculus.
  #   All exceptions classes defined by Cuniculus descend from this class.
  # * `Cuniculus::BadlyFormattedPayload`: A Cuniculus consumer received an
  #   improperly formatted job message.
  # * `Cuniculus::ConfigError`: Incorrect configuration passed to Cuniculus.
  # * `Cuniculus::RMQConnectionError`: Unable to connect to RabbitMQ.
  # * `Cuniculus::RMQQueueConfigurationConflict`: The queue configuration
  #   given to Cuniculus conflicts with the current configuration of the same
  #   existing queue in RabbitMQ.
  # * `Cuniculus::WorkerOptionsError`: Invalid options passed to cuniculus_options.

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

  # Dev note:
  # As explained [here](https://github.com/jeremyevans/sequel/commit/24681efad0fec48195e43801c224bf18cdc8be13#diff-64cd7b67eccdc6dfa69c23b3b19f34e318f9e6827c5dee5f6e845b2993ab035c), empty classes created
  # with `Class.new` require about 200 bytes less memory than ones created as `class MyClass; end`.
  # The call to `name` is used so that the names of such classes are cached before runtime.
  (
    BadlyFormattedPayload = Class.new(Error)
  ).name

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
    WorkerOptionsError = Class.new(Error)
  ).name
end
