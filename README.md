# Cuniculus

Ruby job queue backed by RabbitMQ. The word _cuniculus_ comes from the scientific name of the European rabbit (Oryctolagus cuniculus).

## Getting started

```
gem install cuniculus
```

> The following minimal example assumes RabbitMQ is running on `localhost:5672`; see the [configuration section](#configuration) for how to change this.

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

There is also a more complete example in the Cuniculus repository itself. To run it, clone the repository, then
- start the Ruby and RabbitMQ containers using [Docker Compose](https://docs.docker.com/compose/):
  ```
  docker-compose up -d
  ```
- from within the _cuniculus_ container, produce a job:
  ```
  ruby -Ilib examples/produce.rb
  ```
- also from within the container, start the consumer:
  ```
  bin/cuniculus -I examples/ -r example/init_cuniculus.rb
  ```

## Configuration

Configuration is done through code, using `Cuniculus.configure`. 

Example:
```ruby
require "cuniculus"

# The following Hash is passed as is to Bunny, the library that integrates with RabbitMQ.
rabbitmq_conn = {
    host: 'rabbitmq', # default is 127.0.0.1
    port: 5672,
    ssl: false,
    vhost: '/',
    user: 'guest',
    pass: 'guest',
    auth_mechanism: 'PLAIN',
}

Cuniculus.configure do |cfg|
  cfg.rabbitmq_opts = rabbitmq_conn
  cfg.pub_thr_pool_size = 5         # Only affects job producers
end
```

## How it works

Cuniculus code and conventions are very much inspired by another Ruby job queue library: [Sidekiq](https://github.com/mperham/sidekiq).

To communicate with RabbitMQ, Cuniculus uses [Bunny](https://github.com/ruby-amqp/bunny).

The first time an async job is produced, a thread pool is created, each thread with its own communication channel to RabbitMQ. These threads push jobs to RabbitMQ.

For consuming, each queue will have a corresponding thread pool (handled by Bunny) for concurrency.

## License

Cuniculus is licensed under the "BSD 2-Clause License". See [LICENSE](./LICENSE) for details.

