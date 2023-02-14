# frozen_string_literal: true

require "socket"
require "thread"
require "rackup/handler"
require "rack/request"

module Cuniculus
  module Plugins
    # The HealthCheck plugin starts a Rack server after consumers are initialized, for health probing.
    # It currently does not perform any additional checks and returns '200 OK' regardless of whether
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
    # Options may be passed as well:
    # ```ruby
    # opts = {
    #   "bind_to" => "127.0.0.1", # Default: "0.0.0.0"
    #   "port" => 8080            # Default: 3000
    #   "path" => "alive"         # Default: "healtcheck"
    # }
    # Cuniculus.plugin(:health_check, opts)
    # ```
    # This starts the server bound to 127.0.0.1 and port 8080, and responds on path "alive".
    # The server responds with 404 when requests are made to different paths.
    module HealthCheck
      DEFAULTS = {
        "bind_to" => "0.0.0.0",
        "path" => "healthcheck",
        "port" => 3000,
        "quiet" => false,
        "server" => "webrick",
        "block" => nil
      }.freeze

      OPTS_KEY = "__health_check_opts" # Key in the global plugin options where `:health_check` plugin options are stored.

      # Configure `health_check` plugin
      #
      # @param plugins_cfg [Hash] Global plugin config hash, passed by Cuniculus. This should not be modified by plugin users.
      # @param opts [Hash] Plugin specific options.
      # @option opts [String] "bind_to" ("0.0.0.0") IP address to bind to.
      # @option opts [String] "path" ("healthcheck") Request path to respond to. Requests to other paths will get a 404 response.
      # @option opts [Numeric] "port" (3000) Port number to bind to.
      # @option opts [Boolean] "quiet" (false) Disable server logging to STDOUT and STDERR.
      # @option opts [String] "server" ("webrick") Rack server handler to use .
      def self.configure(plugins_cfg, opts = {}, &block)
        opts = opts.transform_keys(&:to_s)
        invalid_opts = opts.keys - DEFAULTS.keys
        raise Cuniculus::Error, "Invalid option keys for :health_check plugin: #{invalid_opts}" unless invalid_opts.empty?

        plugins_cfg[OPTS_KEY] = h = opts.slice("bind_to", "path", "port", "quiet", "server")
        h["block"] = block if block
        DEFAULTS.each do |k, v|
          h[k] = v if v && !h.key?(k)
        end
      end

      module SupervisorMethods
        def initialize(config)
          super(config)
          hc_plugin_opts = config.opts[OPTS_KEY]
          @hc_server = Rackup::Handler.get(hc_plugin_opts["server"])
          @hc_rack_app = build_rack_app(hc_plugin_opts)
        end

        def start
          start_health_check_server
          super
        end

        def stop
          @hc_server.shutdown
          super
        end


        private

        def build_rack_app(opts)
          app = ::Object.new
          app.define_singleton_method(:call) do |env|
            if Rack::Request.new(env).path == "/#{opts['path']}"
              [200, {}, ["OK"]]
            else
              [404, {}, ["Not Found"]]
            end
          end
          app
        end

        def start_health_check_server
          opts = config.opts[OPTS_KEY]
          Thread.new do
            access_log = opts["quiet"] ? [] : nil
            @hc_server.run(@hc_rack_app, AccessLog: access_log, Port: opts["port"], Host: opts["bind_to"])
          end
        end
      end
    end

    register_plugin(:health_check, HealthCheck)
  end
end

