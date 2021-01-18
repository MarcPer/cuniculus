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
  cfg.pub_thr_pool_size = 5
end

MyWorker.perform_async("x", [1, 2, 3])
