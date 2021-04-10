# frozen_string_literal: true

require "cuniculus"
require_relative "my_worker"

rabbitmq_conn = {
  host: "rabbitmq",
  port: 5672,
  ssl: false,
  vhost: "/",
  user: "guest",
  pass: "guest",
  auth_mechanism: "PLAIN"
}

Cuniculus.configure do |cfg|
  cfg.rabbitmq_opts = rabbitmq_conn
  cfg.add_queue({ "name" => "my_queue", "durable" => true })
  cfg.pub_pool_size = 5
end

print "Producing "
10.times do |i|
  Examples::MyWorker.perform_async(i)
  sleep 2
  print "."
end

Cuniculus.shutdown
