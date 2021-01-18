# frozen_string_literal: true

require "json"

module Cuniculus
  CUNICULUS_EXCHANGE = "cuniculus"
  CUNICULUS_DLX_EXCHANGE = "cuniculus_dlx" # Dead Letter Exchange

  module CuniculusMethods
    # Convert RabbitMQ message into Ruby object for processing.
    def load_job(rmq_msg)
      ::JSON.parse(rmq_msg)
    end

    # Convert Ruby object for publishing to RabbitMQ.
    def dump_job(job)
      ::JSON.dump(job)
    end

    # Convert the +exception+ to the given class.  The given class should be
    # <tt>Cuniculus::Error</tt> or a subclass.  Returns an instance of +klass+ with
    # the message and backtrace of +exception+.
    def convert_exception_class(exception, klass)
      return exception if exception.is_a?(klass)

      e = klass.new("#{exception.class}: #{exception.message}")
      e.wrapped_exception = exception
      e.set_backtrace(exception.backtrace)
      e
    end
  end

  extend CuniculusMethods
end
