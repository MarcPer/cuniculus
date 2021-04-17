![cuniculus_logo](https://user-images.githubusercontent.com/4718658/115109242-de53f900-9f74-11eb-8a46-b93d6f484370.png)


Ruby job queue backed by RabbitMQ. The word _cuniculus_ comes from the scientific name of the European rabbit (Oryctolagus cuniculus).

## Benchmarks

The following measurements were performed with the `bin/run_benchmarks` utility, with different command parameters. Run it with `-h` to see its usage.

To simulate network latency, [Toxiproxy](https://github.com/Shopify/toxiproxy) was used. It needs to be started with `toxiproxy-server` before running the benchmarks.

Network latency (_ms_) | Prefetch count       | Throughput (_jobs/s_) | Average latency (_ms_)
----------------------:|---------------------:|----------------------:|----------------------:
1                      | 65535 (max. allowed) | 10225                 | 2
10                     | 65535 (max. allowed) | 9990                  | 13
1                      |                   50 | 8051                  | 2
10                     |                   50 | 2500                  | 13
100                    |                   50 | 481                   | 103
1                      |                   25 | 7824                  | 2
10                     |                   25 | 1824                  | 13
50                     |                   25 | 469                   | 53
1                      |         10 (default) | 5266                  | 2
10                     |         10 (default) | 807                   | 13
1                      |                    1 | 481                   | 2
10                     |                    1 | 81                    | 13

Additional benchmark parameters:
- throughput was measured by consuming 100k jobs;
- job latency was averaged over 200 samples;
- Ruby 2.7.2 was used.

Several remarks can be made:
- Higher prefetch counts lead to higher throughput, but there are downsides of having it too high; see [this reference](https://www.cloudamqp.com/blog/2017-12-29-part1-rabbitmq-best-practice.html#prefetch) on how to properly tune it.
- Network latency has a severe impact on the throughput, and the effect is larger the smaller the prefetch count is.

## Getting started

```sh
gem install cuniculus
```

_The following minimal example assumes RabbitMQ is running on `localhost:5672`; see the [configuration section](#configuration) for how to change this._

Create a worker class:
```ruby
# -- my_worker.rb
require 'cuniculus/worker'

class MyWorker
  include Cuniculus::Worker

  # the queue name is not explicitly given, so "cun_default" is used.

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

The `-I examples` option adds the `examples/` directory into the load path, and `-r example/init_cuniculus.rb` requires `init_cuniculus.rb` prior to starting the consumer. The latter is where configurations such as that described in the next section should be.

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
  cfg.dead_queue_ttl = 1000 * 60 * 60 * 24 * 30 # keep failed jobs for 30 days
  cfg.add_queue({ name: "critical", durable: true, max_retry: 10, prefetch_count: 1})
end
```

To configure the queue used by a worker, used `cuniculus_options`:

```ruby
class MyWorker
  include Cuniculus::Worker

  cuniculus_options queue: "critical"
  def perform
    # code
  end
end
```

## Error handling

By default, exceptions raised when consuming a job are logged to STDOUT. This can be overriden with the `Cuniculus.error_handler` method:

```ruby
Cuniculus.error_handler do |e|
  puts "Oh nein! #{e}"
end
```

The method expects a block that will receive an exception, and run in the scope of the Worker instance.

## Retry mechanism

Retries are enabled by default (with 8 retries) with an exponential backoff, meaning the time between retries increases the more failures happen. The formula for calculating the times between retries can be found in {Cuniculus::QueueConfig}, namely in the `x-message-ttl` line. As an example, the time between the 7th and 8th retries is roughly 29 days.

Given a declared queue in the configuration, Cuniculus starts on RabbitMQ the corresponding base queue, in addition to its retry queues. As an example, let's consider the default queue `cun_default`: Cuniculus declares a `cun_default` queue, together with some `cun_default_{n}` queues used for job retries.

When a job raises an exception, it is placed into the `cun_default_1` queue for the first retry. It stays there for some pre-defined time, and then gets moved back into the `cun_default` queue for execution.

If it fails again, it gets moved to `cun_default_2`, where it stays for a longer period until it's moved back directly into the `cun_default` queue again.

This goes on until there are no more retry attempts, in which case the job gets moved into the `cun_dead` queue. It can be then only be moved back into the `cun_default` queue manually; otherwise it is discarded after some time, defined as the {Cuniculus::Config.dead_queue_ttl}, in milliseconds (by default, 180 days).

Note that if a job cannot even be parsed, it is moved straight to the dead queue, as there's no point in retrying.

## Health check plugin

Cuniculus ships with a health check plugin. When enabled, a Rack server is started (therefore the [Rack](https://github.com/rack/rack) gem is required, as well as the used handler), which responds with `200 OK` upon receiving a request in the configured port and path.

Enable it with `Cuniculus.plugin(:health_check)`, which binds the server to `0.0.0.0:3000`, listening on the `/healthcheck` path. To configure the server, pass additional options:

```ruby
Cuniculus.plugin(:health_check, { "bind_to" => "127.0.0.1", "port" => 3003, "path" => "ping" })
```

Check {Cuniculus::Plugins::HealthCheck} for further details.

_Note that the default handler "webrick" is not bundled by default with Ruby 3 and needs to be installed separately, if it is to be used._

## How it works

Cuniculus code and conventions are very much inspired by another Ruby job queue library: [Sidekiq](https://github.com/mperham/sidekiq).

To communicate with RabbitMQ, Cuniculus uses [Bunny](https://github.com/ruby-amqp/bunny).

The first time an async job is produced, a thread pool is created, each thread with its own communication channel to RabbitMQ. These threads push jobs to RabbitMQ.

For consuming, each queue will have a corresponding thread pool (handled by Bunny) for concurrency.

## License

Cuniculus is licensed under the "BSD 2-Clause License". See [LICENSE](./LICENSE) for details.

