# frozen_string_literal: true

require "net/http"
require "cuniculus/core"

class RMQControl
  RMQ_HOST = ENV["RMQ_HOST"] || "rabbitmq"

  class << self
    def get_queues
      require "json"
      res = Net::HTTP.start(RMQ_HOST, 15672) do |http|
        uri = URI("http://#{RMQ_HOST}:15672/api/queues/%2F")
        req = Net::HTTP::Get.new(uri) 
        req.basic_auth "guest", "guest"
        http.request(req)
      end
      parsed = JSON.parse(res.body)
      parsed.map { |x| x["name"] }
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
      require "json"
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

