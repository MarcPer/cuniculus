# frozen_string_literal: true

require 'cuniculus'
require 'my_worker'

rabbitmq_conn = {
    host: 'rabbitmq',
    port: 5672,
    ssl: false,
    vhost: '/',
    user: 'guest',
    pass: 'guest',
    auth_mechanism: 'PLAIN',
}

Cuniculus.configure_consumer do |cfg|
  cfg.rabbitmq_opts = rabbitmq_conn
end

