# Puma Statsd Plugin

[Puma][puma] integration with [statsd](statsd) for easy tracking of key metrics
that puma can provide:

* puma.workers
* puma.booted_workers
* puma.running
* puma.backlog
* puma.pool_capacity
* puma.max_threads

Puma already natively supports [socket activation][socket-activation].

  [puma]: https://github.com/puma/puma
  [statsd]: https://github.com/etsy/statsd

## Installation

Add this gem to your Gemfile with puma and then bundle:

```ruby
gem "puma"
gem "puma-plugin-statsd"
```

Add it to your puma config:

```ruby
# config/puma.rb

bind "http://127.0.0.1:9292"

workers 1
threads 8, 16

plugin :statsd
```

## Usage

Ensure you have an environment variable set that points to a statsd host, then boot your puma app as usual

STATSD_HOST=127.0.0.1 bundle exec puma

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/yob/puma-plugin-statsd.

## License

The gem is available as open source under the terms of the [MIT License][license].

  [license]: http://opensource.org/licenses/MIT
