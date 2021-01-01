# frozen_string_literal: true

require 'cuniculus'
require_relative 'my_worker'

rabbitmq_conn = {
    host: 'rabbitmq',
    port: 5672,
    ssl: false,
    vhost: '/',
    user: 'guest',
    pass: 'guest',
    auth_mechanism: 'PLAIN',
}

Cuniculus.configure_producer do |cfg|
  cfg.rabbitmq_opts = rabbitmq_conn
  cfg.pool_size = 5
end

MyWorker.perform_async('x', [1, 2, 3])
