# frozen_string_literal: true

require "bunny"
require "cuniculus/pub_worker"

module Cuniculus
  # The dispatcher forwards jobs to a worker pool to be published to RabbitMQ.
  # It holds a RabbitMQ session and, when it receives information from one of its workers
  # that a network exception occurred, tries to reestablish the connection and restarts
  # the pool.
  #
  # The dispatcher background thread, which monitors for connection errors, is started
  # whenever the first job is enqueued by a {Cuniculus::Worker}.
  class Dispatcher
    ENFORCED_CONN_OPTS = {
      threaded: false, # No need for a reader thread, since this connection is only used for publishing
      automatically_recover: false,
      logger: ::Logger.new(IO::NULL)
    }.freeze
    RECOVERABLE_ERRORS = [AMQ::Protocol::Error, ::Bunny::Exception, Errno::ECONNRESET].freeze

    attr_reader :dispatcher_chan, :job_queue, :reconnect_attempts, :reconnect_delay, :reconnect_delay_max, :shutdown_grace_period

    # Instantiates a dispatcher using the passed {Cuniculus::Config}.
    #
    # @param config [Cuniculus::Config]
    def initialize(config)
      @config = config
      @conn = nil
      @job_queue = Queue.new
      @dispatcher_chan = Queue.new
      @shutdown = false
      @workers = config.pub_pool_size.times.map do |i|
        Cuniculus::PubWorker.new(config, @job_queue, @dispatcher_chan)
      end
      @reconnect_attempts = config.pub_reconnect_attempts
      @reconnect_delay = config.pub_reconnect_delay
      @reconnect_delay_max = config.pub_reconnect_delay_max
      @shutdown_grace_period = config.pub_shutdown_grace_period
      @thread = nil
      @shutdown = false
    end

    def describe(log_level = Logger::DEBUG)
      Cuniculus.logger.info @thread&.backtrace
      @workers.each do |w|
        Cuniculus.logger.log(log_level, w.instance_variable_get(:@thread)&.backtrace)
      end
    end


    # Starts a thread responsible for reestablishing lost RabbitMQ connections and
    # restarting {Cuniculus::PubWorker}s.
    #
    # It keeps track of the last time it had to reconnect, in case it receives outdated
    # messages of failed connections from workers.
    #
    # PubWorkers communicate to it through its `dispatcher_chan` queue.
    # Depending on the content fetched from the dispatcher channel, it takes different actions:
    # - when a :shutdown message is received, it waits until current jobs are finished (up to the configured `shutdown_grace_period`) and stops its background thread.
    # - when a timestamp is received that is smaller than the last reconnect timestamp, the message is ignored
    # - when the timestamp is larger than the last reconnect timestamp, it tries to reestablish the connection to RabbitMQ and restarts its workers.
    #
    # Note that the first time the dispatcher is started, it sends a message to its own background thread with a timestamp to trigger the first connection.
    def start!
      return if @shutdown || @thread&.alive?
      @thread = Thread.new do
        last_connect_time = 0
        loop do
          disconnect_time = @dispatcher_chan.pop
          break if disconnect_time == :shutdown
          if disconnect_time > last_connect_time
            recover_from_net_error
            last_connect_time = Cuniculus.mark_time
          end
        end
      end
      @conn = ::Bunny.new(@config.rabbitmq_opts.merge(ENFORCED_CONN_OPTS).merge(session_error_handler: @thread))
      @dispatcher_chan << Cuniculus.mark_time
    end

    # Whether its background thread is running.
    #
    # @return [Boolean]
    def alive?
      @thread&.alive? || false
    end

    # Starts connection to RabbitMQ followed by starting the workers background threads.
    #
    # if it fails to connect, it keeps retrying for a certain number of attempts, defined by
    # {Config.pub_reconnect_attempts}. For unlimited retries, this value should be set to `:infinite`.
    #
    # The time between reconnect attempts follows an exponential backoff formula:
    #
    # ```
    # t = delay * 2^(n-1)
    # ```
    #
    # where n is the attempt number, and delay is defined by {Config.pub_reconnect_delay}.
    #
    # If {Config.pub_reconnect_delay_max} is defined, it works as a cap for the above time.
    # @return [void]
    def recover_from_net_error
      attempt = 0
      begin
        @conn.start
        Cuniculus.logger.info("Connection established")

        @workers.each { |w| w.start!(@conn) }
      rescue *RECOVERABLE_ERRORS => ex
        handle_error(Cuniculus.convert_exception_class(ex, Cuniculus::RMQConnectionError))
        sleep_time = @shutdown ? 1 : [(reconnect_delay * 2**(attempt-1)), reconnect_delay_max].min
        sleep sleep_time
        attempt += 1

        retry if @shutdown && attempt <= reconnect_delay_max
        retry if reconnect_attempts == :infinite || attempt <= reconnect_attempts
      end
    end

    # Shutdown workers, giving them time to conclude outstanding tasks.
    #
    # Shutdown is forced after {Config.pub_shutdown_grace_period} seconds.
    #
    # @return [void]
    def shutdown
      Cuniculus.logger.info("Cuniculus: Shutting down dispatcher")
      @shutdown = true
      alive_size = @workers.size
      shutdown_t0 = Cuniculus.mark_time

      sleep 1 until Cuniculus.mark_time - shutdown_t0 > shutdown_grace_period || @job_queue.empty?

      until Cuniculus.mark_time - shutdown_t0 > shutdown_grace_period || (alive_size = @workers.select(&:alive?).size) == 0
        sleep 1
        alive_size.times { @job_queue << :shutdown }
      end

      @dispatcher_chan << :shutdown
      alive_size = @workers.select(&:alive?).size
      return unless alive_size > 0

      Cuniculus.logger.warn("Cuniculus: Forcing shutdown with #{alive_size} workers remaining")
      describe
    end

    private

    def handle_error(e)
      Cuniculus.logger.error("#{e.class.name}: #{e.message}")
      Cuniculus.logger.error(e.backtrace.join("\n")) unless e.backtrace.nil?
    end
  end
end

