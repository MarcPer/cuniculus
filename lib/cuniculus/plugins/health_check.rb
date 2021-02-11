# frozen_string_literal: true

require "socket"
require "thread"

module Cuniculus
  module Plugins
    module HealthCheck
      HEALTH_CHECK_RESPONSE = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK"

      def self.configure(opts, bind_to = "0.0.0.0", port = 3000, &block)
        opts["__health_check_opts"] = {
          "bind_to" => bind_to,
          "port" => port
        }
        opts["__health_check_opts"]["block"] = block if block
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
          opts = config.opts["__health_check_opts"]
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

