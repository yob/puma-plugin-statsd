# Puma Dogstatsd Plugin

[Puma](https://github.com/puma/puma) integration with [dogstatsd](https://github.com/DataDog/dogstatsd-ruby) for easy tracking of key metrics that puma can provide:

* puma.workers
* puma.booted_workers
* puma.running
* puma.backlog
* puma.pool_capacity
* puma.max_threads

## Installation

Add this gem to your Gemfile with puma and then bundle:

```ruby
gem "puma"
gem "puma-plugin-dogstatsd"
```

Add it to your puma config:

```ruby
# config/puma.rb

bind "http://127.0.0.1:9292"

workers 1
threads 8, 16

PumaPluginDogstastd.activate(self, an_instance_of_a_dogstatsd_client)
```

## Acknowledgements

This gem is a fork of the excellent [puma-plugin-statsd](https://github.com/yob/puma-plugin-statsd) by James Healy.

Other puma plugins that were helpful references:

* [puma-heroku](https://github.com/evanphx/puma-heroku)
* [tmp-restart](https://github.com/puma/puma/blob/master/lib/puma/plugin/tmp_restart.rb)
* [puma-plugin-systemd](https://github.com/sj26/puma-plugin-systemd)

The [puma docs](https://github.com/puma/puma/blob/master/docs/plugins.md) were also helpful.

## License

The gem is available as open source under the terms of the [MIT License][license].

  [license]: http://opensource.org/licenses/MIT
