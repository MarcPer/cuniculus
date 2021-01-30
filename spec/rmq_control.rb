# frozen_string_literal: true

require "json"
require "net/http"
require "cuniculus/core"

class RMQControl
  RMQ_HOST = ENV["RMQ_HOST"] || "rabbitmq"

  class << self
    def wait_live(timeout)
      count = 0
      loop do
        break if count >= timeout
        begin
          res = Net::HTTP.start(RMQ_HOST, 15672) do |http|
            uri = URI("http://#{RMQ_HOST}:15672/api/aliveness-test/%2F")
            req = Net::HTTP::Get.new(uri)
            req.basic_auth "guest", "guest"
            http.request(req)
          end

          parsed = JSON.parse(res.body)
          return if parsed["status"] == "ok"
        rescue StandardError
        end

        sleep 1
        count += 1
      end

      raise "Timeout waiting for RMQ to start" if count >= timeout
    end

    def get_queues
      res = Net::HTTP.start(RMQ_HOST, 15672) do |http|
        uri = URI("http://#{RMQ_HOST}:15672/api/queues/%2F")
        req = Net::HTTP::Get.new(uri)
        req.basic_auth "guest", "guest"
        http.request(req)
      end
      parsed = JSON.parse(res.body)
      parsed.map { |x| x["name"] }
    end

    def get_bindings(exchange_name)
      res = Net::HTTP.start(RMQ_HOST, 15672) do |http|
        uri = URI("http://#{RMQ_HOST}:15672/api/exchanges/%2F/#{exchange_name}/bindings/source")
        req = Net::HTTP::Get.new(uri)
        req.basic_auth "guest", "guest"
        http.request(req)
      end
      parsed = JSON.parse(res.body)
      parsed.select { |b| b["destination_type"] == "queue" }.map { |x| x["destination"] }
    end

    def delete_queues(queue_names)
      Net::HTTP.start(RMQ_HOST, 15672) do |http|
        queue_names.each do |queue_name|
          uri = URI("http://#{RMQ_HOST}:15672/api/queues/%2F/#{queue_name}")
          req = Net::HTTP::Delete.new(uri)
          req.basic_auth "guest", "guest"
          http.request(req)
        end
      end
    end

    def get_exchanges
      res = Net::HTTP.start(RMQ_HOST, 15672) do |http|
        uri = URI("http://#{RMQ_HOST}:15672/api/exchanges/%2F")
        req = Net::HTTP::Get.new(uri)
        req.basic_auth "guest", "guest"
        http.request(req)
      end
      parsed = JSON.parse(res.body)
      parsed.map { |x| x["name"] }
    end

    def delete_exchanges
      Net::HTTP.start(RMQ_HOST, 15672) do |http|
        [Cuniculus::CUNICULUS_EXCHANGE, Cuniculus::CUNICULUS_DLX_EXCHANGE].each do |x|
          uri = URI("http://#{RMQ_HOST}:15672/api/exchanges/%2F/#{x}")
          req = Net::HTTP::Delete.new(uri)
          req.basic_auth "guest", "guest"
          http.request(req)
        end
      end
    end
  end
end

