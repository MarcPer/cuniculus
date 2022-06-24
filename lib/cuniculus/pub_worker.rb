# frozen_string_literal: true

require "bunny"

module Cuniculus
  # Each PubWorker maintains a background thread in a loop, fetching jobs reaching
  # its job queue and publishing the payloads to RabbitMQ. They are not instantiated
  # directly, but are rather created and managed by a {Cuniculus::Dispatcher}.
  class PubWorker
    def initialize(config, job_queue)
      @config = config
      @job_queue = job_queue
      @mutex = Mutex.new
      @alive = false
    end

    # Declares exchanges, and starts a background thread that consumes and publishes messages.
    #
    # If the connection to RabbitMQ it receives is not established, or if it fails to declare
    # the exchanges, the background thread is not started and a message is sent to the
    # dispatcher channel with the current timestamp. The dispatcher is then responsible for
    # trying to set the connection up again and starting each of its workers.
    #
    # @param conn [::Bunny::Session] Connection to RabbitMQ. Expected to be open at this stage.
    def start!(conn)
      @channel = conn.create_channel
      @x = @channel.direct(Cuniculus::CUNICULUS_EXCHANGE, { durable: true })
      @dlx = @channel.fanout(Cuniculus::CUNICULUS_DLX_EXCHANGE, { durable: true })
      @alive = true
      run
    end

    # Whether the background thread is running.
    #
    # @return [Boolean]
    def alive?
      @alive
    end

    private

    # Starts the job consuming loop. This is used internally by `start!` and runs in
    # a background thread. Messages are published to RabbitMQ.
    #
    # The loop is finished if the message `:shutdown` is retrieved from the job queue or
    # if an exception happens while trying to publish a message to RabbitMQ. In the
    # latter case, the job is reinserted into the job queue, and a message with the timestamp
    # is sent into the dispatcher channel, so that it can try restart the connection
    # and the workers again.
    def run
      loop do
        case msg = @job_queue.pop
        when :shutdown
          break
        else
          xname, payload, routing_key = msg
          exchange = if xname == CUNICULUS_DLX_EXCHANGE
                        @dlx
                     else
                        @x
                     end
          begin
            exchange.publish(payload, { routing_key: routing_key, persistent: true })
          rescue *::Cuniculus::Dispatcher::RECOVERABLE_ERRORS
            @job_queue << [xname, payload, routing_key]
            break
          end
        end
      end
      @alive = false
      @channel.close unless @channel.closed?
    end

    def sync(&block)
      @mutex.synchronize(&block)
    end
  end
end
