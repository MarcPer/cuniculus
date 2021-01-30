# frozen_string_literal: true

require "cuniculus/core"
require "cuniculus/logger"

module Cuniculus
  class Consumer
    POLL_TIME = 5
    JOB_REQUIRED_KEYS = %w[class args].freeze

    attr_reader :channel, :exchange, :job_queue, :queue_config

    def initialize(queue_config, channel)
      @channel = channel
      @queue_config = queue_config
    end

    def start
      @exchange = channel.direct(Cuniculus::CUNICULUS_EXCHANGE, { durable: true })
      # channel.direct(Cuniculus::CUNICULUS_DLX_EXCHANGE, { durable: true })
      @job_queue = queue_config.declare!(channel)
      @_consumer = job_queue.subscribe(manual_ack: true, block: false) do |delivery_info, properties, payload|
        run_job(delivery_info, properties, payload)
      end
    end

    def stop
      @_consumer&.cancel
      channel.close unless channel.closed?
    end

    def run_job(delivery_info, _properties, payload)
      item = parse_job(payload)
      klass = Object.const_get(item["class"])
      worker = klass.new
      worker.perform(*item["args"])
      channel.ack(delivery_info.delivery_tag, false)
    rescue Cuniculus::BadlyFormattedPayload => ex
      handle_error(ex)
      # If parse failed, send message straight to DLX
      channel.nack(delivery_info.delivery_tag, false, false)
    rescue StandardError => ex
      handle_error(Cuniculus.convert_exception_class(ex, Cuniculus::Error))
      maybe_retry(delivery_info, item)
    end

    def parse_job(payload)
      msg = Cuniculus.load_job(payload)
      raise Cuniculus::BadlyFormattedPayload, "Consumed message with missing information: #{payload}\nIt should have keys [#{JOB_REQUIRED_KEYS.join(', ')}]" unless (JOB_REQUIRED_KEYS - msg.keys).empty?

      msg
    rescue Cuniculus::BadlyFormattedPayload
      raise
    rescue StandardError => ex
      raise Cuniculus.convert_exception_class(ex, Cuniculus::BadlyFormattedPayload), "Badly formatted consumed message: #{payload}"
    end

    def maybe_retry(delivery_info, item)
      retry_count = item["_cun_retries"].to_i
      retry_queue_name = job_queue.retry_queue(retry_count)
      unless retry_queue_name
        channel.nack(delivery_info.delivery_tag, false, false)
        return
      end
      payload = Cuniculus.dump_job(item.merge("_cun_retries" => retry_count + 1))
      exchange.publish(
        payload,
        {
          routing_key: retry_queue_name,
          persistent: true
        }
      )
      channel.ack(delivery_info.delivery_tag, false)
    end

    def handle_error(e)
      Cuniculus.logger.error("#{e.class.name}: #{e.message}")
      Cuniculus.logger.error(e.backtrace.join("\n")) unless e.backtrace.nil?
    end

    def constantize(str)
      return Object.const_get(str) unless str.include?("::")

      names = str.split("::")
      names.shift if names.empty? || names.first.empty?

      names.inject(Object) do |constant, name|
        constant.const_get(name, false)
      end
    end
  end
end
