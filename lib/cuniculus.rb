# frozen_string_literal: true

require "cuniculus/version"

raise "Cuniculus #{Cuniculus.version} does not support Ruby versions below 2.7.2." if RUBY_PLATFORM != "java" && Gem::Version.new(RUBY_VERSION) < Gem::Version.new("2.7.2")

require "cuniculus/logger"
require "cuniculus/config"
require "cuniculus/rmq_pool"

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

  def self.log_formatter
    @log_formatter ||= Cuniculus::Logger::Formatters::Standard.new
  end
end
