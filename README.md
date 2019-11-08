# Puma Statsd Plugin

[Puma][puma] integration with [statsd](statsd) for easy tracking of key metrics
that puma can provide:

* puma.workers
* puma.booted_workers
* puma.running
* puma.backlog
* puma.pool_capacity
* puma.max_threads

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


Add the following to your config/puma.rb:

```
if ENV['KUBERNETES_SERVICE_HOST'] && ENV['PERFTOOLS_DATADOG_HOST']
  plugin :statsd

  ::PumaStatsd.configure do |config|
    config.pod_name = ENV['HOSTNAME']
    # Extract deployment name from pod name
    config.statsd_grouping = ENV['HOSTNAME'].sub(/\-[a-z0-9]+\-[a-z0-9]{5}$/, '')
    config.statsd_host = ENV['PERFTOOLS_DATADOG_HOST']
    config.statsd_port = ENV['PERFTOOLS_DATADOG_PORT']
  end
end
```

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/yob/puma-plugin-statsd.

## Testing the data being sent to statsd

Start a pretend statsd server that listens for UDP packets on port 8125:

    ruby devtools/statsd-to-stdout.rb

Start puma:

    STATSD_HOST=127.0.0.1 bundle exec puma devtools/config.ru --config devtools/puma-config.rb

Throw some traffic at it, either with curl or a tool like ab:

    curl http://127.0.0.1:9292/
    ab -n 10000 -c 20 http://127.0.0.1:9292/ 

Watch the output of the UDP server process - you should see statsd data printed to stdout.

## Acknowledgements

This gem is a fork of the excellent [puma-plugin-systemd][puma-plugin-systemd] by
Samuel Cochran.

  [puma-plugin-systemd]: https://github.com/sj26/puma-plugin-systemd

Other puma plugins that were helpful references:

* [puma-heroku](https://github.com/evanphx/puma-heroku)
* [tmp-restart](https://github.com/puma/puma/blob/master/lib/puma/plugin/tmp_restart.rb)

The [puma docs](https://github.com/puma/puma/blob/master/docs/plugins.md) were also helpful.

## License

The gem is available as open source under the terms of the [MIT License][license].

  [license]: http://opensource.org/licenses/MIT
