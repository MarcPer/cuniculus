# frozen_string_literal: true

require "cuniculus"
require "my_worker"

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
end

Cuniculus.error_handler do |e|
  puts "Oh nein! #{e}"
end

Cuniculus.plugin(:health_check, { "bind_to" => "0.0.0.0", "port" => 3000 })
