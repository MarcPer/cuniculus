# frozen_string_literal: true

require "cuniculus/version"

raise "Cuniculus #{Cuniculus.version} does not support Ruby versions below 2.7.2." if RUBY_PLATFORM != "java" && Gem::Version.new(RUBY_VERSION) < Gem::Version.new("2.7.2")

require "cuniculus/logger"
require "cuniculus/config"
require "cuniculus/plugins"
require "cuniculus/rmq_pool"
require "cuniculus/supervisor"

module Cuniculus
  def self.configure
    cfg = Cuniculus::Config.new
    yield cfg
    cfg.declare!
    @config = cfg
    Cuniculus::RMQPool.configure(cfg)
  end

  def self.config
    @config ||= Cuniculus::Config.new
  end

  def self.logger
    @logger ||= Cuniculus::Logger.new($stdout, level: Logger::INFO)
  end

  def self.error_handler(&block)
    Cuniculus::Consumer.define_method(:handle_error, &block)
    Cuniculus::Consumer.instance_eval { private :handle_error }
  end

  def self.plugin(plugin, *args, &block)
    plugin = Cuniculus::Plugins.load_plugin(plugin) if plugin.is_a?(Symbol)
    raise Cuniculus::Error, "Invalid plugin type: #{plugin.class.inspect}. It must be a module" unless plugin.is_a?(Module)

    self::Supervisor.send(:include, plugin::SupervisorMethods) if defined?(plugin::SupervisorMethods)
    self::Supervisor.send(:extend, plugin::SupervisorClassMethods) if defined?(plugin::SupervisorClassMethods)
    plugin.configure(config.opts, *args, &block) if plugin.respond_to?(:configure)
  end
end
