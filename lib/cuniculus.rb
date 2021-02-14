# frozen_string_literal: true

require "cuniculus/version"

raise "Cuniculus #{Cuniculus.version} does not support Ruby versions below 2.7.2." if RUBY_PLATFORM != "java" && Gem::Version.new(RUBY_VERSION) < Gem::Version.new("2.7.2")

require "cuniculus/logger"
require "cuniculus/config"
require "cuniculus/plugins"
require "cuniculus/rmq_pool"
require "cuniculus/supervisor"

# Base definition of the Cuniculus Module
module Cuniculus

  # Configure Cuniculus.
  #
  # @yield [Cuniculus::Config]
  #
  # @example Change RabbitMQ connection details.
  #   Cuniculus.configure do |cfg|
  #     cfg.rabbitmq_opts = { host: 'rmq.mycompany.com', user: 'guest', pass: 'guest' }
  #   end
  def self.configure
    cfg = Cuniculus::Config.new
    yield cfg
    cfg.declare!
    @config = cfg
    Cuniculus::RMQPool.configure(cfg)
  end

  # Current config of Cuniculus
  #
  # Returns config for read-only purpose. Use {Cuniculus.configure Cuniculus.configure} to change the configured values.
  #
  # @return [Cuniculus::Config]
  def self.config
    @config ||= Cuniculus::Config.new
  end

  # Current Cuniculus logger
  #
  # @return [Cuniculus::Logger]
  def self.logger
    @logger ||= Cuniculus::Logger.new($stdout, level: Logger::INFO)
  end

  # Receives a block that is called when the job consumer encounters an error.
  # The block receives the exception object and runs in the context of the consumer instance.
  #
  # Note that overriding the default error handler does not affect the retry mechanism. This error handler
  # is designed to be used for logging.
  #
  # The default error handler is defined in {Cuniculus::Consumer#handle_error}.
  #
  # @example Send error info to an external service.
  #   Cuniculus.error_handler do |e|
  #     err = "#{e.class.name}: #{e.message}"
  #     bt = e.backtrace.join("\n") unless e.backtrace.nil?
  #     MyLogginService.error(err, bt)
  #   end
  def self.error_handler(&block)
    Cuniculus::Consumer.define_method(:handle_error, &block)
    Cuniculus::Consumer.instance_eval { private :handle_error }
  end

  # Load a plugin. If plugin is a Module, it is loaded directly.
  # If it is a symbol, then it needs to satisfy the following:
  # - The call `require "cuniculus/plugins/#{plugin}"` should succeed
  # - The required plugin must register itself by calling {Cuniculus::Plugins.register_plugin}
  #
  # The additional arguments and block are passed to the plugin's `configure` method, if it exists.
  #
  # @param plugin [Symbol, Module]
  # @param args [Array<Object>] *args passed to the plugin's `configure` method
  # @param [Block] block passed to the plugin's `configure` method
  #
  # @example Enable `:health_check` plugin
  #   Cuniculus.plugin(:health_check)
  def self.plugin(plugin, *args, &block)
    plugin = Cuniculus::Plugins.load_plugin(plugin) if plugin.is_a?(Symbol)
    raise Cuniculus::Error, "Invalid plugin type: #{plugin.class.inspect}. It must be a module" unless plugin.is_a?(Module)

    self::Supervisor.send(:include, plugin::SupervisorMethods) if defined?(plugin::SupervisorMethods)
    self::Supervisor.send(:extend, plugin::SupervisorClassMethods) if defined?(plugin::SupervisorClassMethods)
    plugin.configure(config.opts, *args, &block) if plugin.respond_to?(:configure)
  end
end
