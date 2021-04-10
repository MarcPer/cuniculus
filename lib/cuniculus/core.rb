# frozen_string_literal: true

require "json"

module Cuniculus
  CUNICULUS_EXCHANGE = "cuniculus"
  CUNICULUS_DLX_EXCHANGE = "cuniculus_dlx" # Dead Letter Exchange

  # Core Cuniculus methods
  module CuniculusMethods
    # Convert a RabbitMQ message into Ruby object for processing.
    def load_job(rmq_msg)
      ::JSON.parse(rmq_msg)
    end

    # Serializes a Ruby object for publishing to RabbitMQ.
    def dump_job(job)
      ::JSON.dump(job)
    end

    # Convert the input `exception` to the given class. The given class should be
    # {Cuniculus::Error} or a subclass.  Returns an instance of `klass` with
    # the message and backtrace of `exception`.
    #
    # @param exception [Exception] The exception being wrapped
    # @param klass [Cuniculus::Error] The subclass of `Cuniculus::Error`
    #
    # @return [Cuniculus::Error] An instance of the input `Cuniculus::Error`
    def convert_exception_class(exception, klass)
      return exception if exception.is_a?(klass)

      e = klass.new("#{exception.class}: #{exception.message}")
      e.wrapped_exception = exception
      e.set_backtrace(exception.backtrace)
      e
    end

    def mark_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  extend CuniculusMethods
end
