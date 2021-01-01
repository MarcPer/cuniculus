# Cuniculus

Ruby job queue backed by RabbitMQ. The word cuniculus comes from the scientific name of the European rabbit (Oryctolagus cuniculus).

## Getting started

```
gem install cuniculus
```

Create a worker class:
```ruby
# -- my_worker.rb
require 'cuniculus/worker'

class MyWorker
  include Cuniculus::Worker

  def perform(arg1, arg2)
    puts "Processing:"
    puts "arg1: #{arg1.inspect}"
    puts "arg2: #{arg2.inspect}"
  end
end
```

Add jobs to queue:
```ruby
MyWorker.perform_async('x', [1, 2, 3])
```

Start the job consumer:
```sh
cuniculus -r my_worker.rb
```

### Example

To run the example from the repository, clone it locally, then
- start the containers using [Docker Compose](https://docs.docker.com/compose/):
  ```
  docker-compose up -d
  ```
- from within the container produce a job:
  ```
  ruby -Ilib examples/produce.rb
  ```
- also from within the container, start the consumer:
  ```
  bin/cuniculus -I examples/ -r example/init_cuniculus.rb
  ```

## Configuration

Configuration is done through code, using `Cuniculus.configure_producer` and `Cuniculus.configure_consumer` to configure the producers and consumers, respectively:

Example consumer configuration:
```ruby
require "cuniculus"

# The following Hash is passed as is to Bunny, the library that integrates with RabbitMQ.
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

```

Example producer configuration:
```ruby
require "cuniculus"

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

```

## How it works

Cuniculus code and conventions are very much inspired by another Ruby job queue library: [Sidekiq](https://github.com/mperham/sidekiq).

To communicate with RabbitMQ, Cuniculus uses [Bunny](https://github.com/ruby-amqp/bunny).

When the producer is configured with `Cuniculus.configure_producer`, a pool of RabbitMQ channels is created for publishing messages.

For consuming, each queue will have a corresponding thread pool (handled by Bunny) for concurrency.

## License

Cuniculus is licensed under the "BSD 2-Clause License", a permissive license equivalent to MIT license. See [LICENSE](./LICENSE) for details.

