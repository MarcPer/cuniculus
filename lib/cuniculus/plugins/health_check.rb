# frozen_string_literal: true

require "socket"
require "thread"

module Cuniculus
  module Plugins
    # The HealthCheck plugin starts a TCP server together with consumers for health probing.
    # It currently does not perform any additional checks returns '200 OK' regardless of whether
    # - the node can connect to RabbitMQ;
    # - consumers are stuck.
    #
    # The healthcheck stays up as long as the supervisor module is also running.
    #
    # Enable the plugin with:
    # ```ruby
    # Cuniculus.plugin(:health_check)
    # ```
    #
    # Options may be passed as well (use `String` keys):
    # ```ruby
    # opts = {
    #   "bind_to" => "127.0.0.1", # Default: "0.0.0.0"
    #   "port" => 8080            # Default: 3000
    # }
    # Cuniculus.plugin(:health_check, opts)
    # ```
    # This starts the server bound to 127.0.0.1 and port 8080.
    #
    # Note that the request path is not considered. The server responds with 200 to any path.
    module HealthCheck
      HEALTH_CHECK_RESPONSE = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK"

      DEFAULTS = {
        "bind_to" => "0.0.0.0",
        "port" => 3000,
        "server" => "webrick",
        "block" => nil
      }.freeze

      OPTS_KEY = "__health_check_opts" # Key in the global plugin options where `:health_check` plugin options are stored.

      # Configure `health_check` plugin
      #
      # @param plugins_cfg [Hash] Global plugin config hash, passed by Cuniculus. This should not be used by plugin users.
      # @param opts [Hash] Plugin specific options.
      # @option opts [String] "bind_to" IP address to bind to (default: "0.0.0.0")
      # @option opts [Numeric] "port" Port number to bind to (default: 3000)
      def self.configure(plugins_cfg, opts = {}, &block)
        invalid_opts = opts.keys - DEFAULTS.keys
        raise Cuniculus::Error, "Invalid option keys for :health_check plugin: #{invalid_opts}" unless invalid_opts.empty?

        plugins_cfg[OPTS_KEY] = h = opts.slice("bind_to", "port", "server")
        h["block"] = block if block
        DEFAULTS.each do |k, v|
          h[k] = v if v && !h.key?(k)
        end
      end

      module SupervisorMethods
        def start
          hc_rd, @hc_wr = IO.pipe
          start_health_check_server(hc_rd)
          super
        end

        def stop
          @hc_wr << "a"
          super
        end


        private

        def start_health_check_server(pipe_reader)
          opts = config.opts[OPTS_KEY]
          server = ::TCPServer.new(opts["bind_to"], opts["port"])

          # If port was assigned by OS (when 'port' option was given as 0),
          # now override input value with it.
          opts["port"] = server.addr[1]
          @hc_thread = Thread.new do
            sock = nil
            done = false
            loop do
              begin
                break if done
                sock = server.accept_nonblock
              rescue IO::WaitReadable, Errno::EINTR
                io = IO.select([server, pipe_reader])
                done = true if io.first.include?(pipe_reader)
                retry
              end

              sock.print HEALTH_CHECK_RESPONSE
              sock.shutdown
            end

            sock&.close if sock && !sock.closed?
          end
        end
      end
    end

    register_plugin(:health_check, HealthCheck)
  end
end

