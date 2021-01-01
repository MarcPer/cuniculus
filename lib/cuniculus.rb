# frozen_string_literal: true

require "cuniculus/version"
fail "Cuniculus #{Cuniculus.version} does not support Ruby versions below 2.7.2." if RUBY_PLATFORM != "java" && Gem::Version.new(RUBY_VERSION) < Gem::Version.new("2.7.2")

require "cuniculus/logger"
require "cuniculus/config/consumer_config"
require "cuniculus/config/producer_config"
require "cuniculus/publishing/rabbitmq_pool"

module Cuniculus
  def self.configure_consumer
    cfg = Cuniculus::Config::ConsumerConfig.new
    yield cfg
    cfg.validate!
    @consumer_config = cfg
  end

  def self.consumer_config
    @consumer_config ||= Cuniculus::Config::ConsumerConfig.default
  end

  def self.configure_producer
    cfg = Cuniculus::Config::ProducerConfig.new
    yield cfg
    cfg.validate!
    Cuniculus::Publishing::RabbitmqPool.init!(cfg)
    @producer_config = cfg
  end

  def self.producer_config
    @producer_config ||= Cuniculus::Config::ProducerConfig.default
  end

  def self.logger
    @logger ||= Cuniculus::Logger.new($stdout, level: Logger::INFO)
  end

  def self.log_formatter
    @log_formatter ||= Cuniculus::Logger::Formatters::Standard.new
  end
end

