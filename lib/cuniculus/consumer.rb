# frozen_string_literal: true

require "cuniculus/core"
require "cuniculus/logger"

module Cuniculus
  class Consumer
    POLL_TIME = 5

    attr_reader :channel, :exchange, :job_queue

    def initialize(queue_config, channel)
      @channel = channel
      @exchange = channel.direct(Cuniculus::CUNICULUS_EXCHANGE, { durable: true })
      @job_queue = queue_config.declare!(channel)
    end

    def start
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

      # If parse failed, send message straight to DLX
      unless item
        Cuniculus.logger.warn("Incorrectly formatted job message: #{payload}")
        channel.nack(delivery_info.delivery_tag, false, false)
        return
      end
      klass = Object.const_get(item["class"])
      worker = klass.new
      worker.perform(*item["args"])
      channel.ack(delivery_info.delivery_tag, false)
    rescue StandardError => ex
      handle_work_error(delivery_info, item)
      Cuniculus.logger.error(ex)
    end

    def parse_job(payload)
      msg = Cuniculus.load_job(payload)
      return nil unless (%w[class args] - msg.keys).empty?

      msg
    rescue StandardError => _ex
      nil
    end

    def handle_work_error(delivery_info, item)
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
