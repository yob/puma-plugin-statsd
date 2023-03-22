# Puma Statsd Plugin

[Puma][puma] integration with [statsd][statsd] for easy tracking of key metrics
that puma can provide:

* puma.workers
* puma.booted_workers
* puma.running
* puma.backlog
* puma.pool_capacity
* puma.max_threads
* puma.old_workers
* puma.requests_count

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

By default the plugin assumes statsd is available at 127.0.0.1. If that's true in your environment, just start puma like normal:

```
bundle exec puma
```

If statsd isn't on 127.0.0.1 or the port is non-standard, you can configure them using optional environment variables:

```
STATSD_HOST=127.0.0.1 STATSD_PORT=9125 bundle exec puma
```

### Datadog Integration

metric tags are a non-standard addition to the statsd protocol, supported by
the datadog "dogstatsd" server.

Should you be reporting the puma metrics to a dogstatsd server, you can set
tags via the following three environment variables.

#### DD_TAGS

`DD_TAGS`: Set this to a space-separated list of tags, using the
[datadog agent standard format](https://docs.datadoghq.com/agent/docker/?tab=standard#global-options).

For example, you could set this environment variable to set three datadog tags,
and then you can filter by in the datadog interface:

```bash
export DD_TAGS="env:test simple-tag-0 tag-key-1:tag-value-1"
bundle exec rails server
```

#### MY_POD_NAME

`MY_POD_NAME`: Set a `pod_name` tag to the metrics. The `MY_POD_NAME`
environment variable is recommended in the datadog kubernetes setup
documentation, and for puma apps deployed to kubernetes it's very helpful to
have the option to report on specific pods.

You can set it on your pods like this:

```yaml
env:
  - name: MY_POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
```

#### STATSD_GROUPING

`STATSD_GROUPING`: add a `grouping` tag to the metrics, with a value equal to
the environment variable value. This is particularly helpful in a kubernetes
deployment where each pod has a unique name but you want the option to group
metrics across all pods in a deployment. Setting this on the pods in a
deployment might look something like:

```yaml
env:
  - name: STATSD_GROUPING
    value: deployment-foo
```

#### STATSD_SLEEP_INTERVAL
Stats loop by default runs every two seconds. You may want to lower that to get more fine grained sampling of the metrics or to stats be able to report quicker after an error. Sleep interval is configurable via `STATSD_SLEEP_INVERVAL` environment variable. For example:

```bash
export STATSD_SLEEP_INTERVAL='0.5'
bundle exec rails server
```

`String#to_f` will be called on provided value.

#### Advanced configuration
You may want to use different environment variable names, for instance if you
happen to already provide same values with another names for another reasons,
and want to avoid duplication. You also may want to compute some values from
other values. Finally, you may want to enable the plugin conditionally. In any
case, there's an interface to configure plugin from ruby. If you want to do so,
you can add the following to your `config/puma.rb` (values are examples):

```ruby
  plugin :statsd

  ::PumaStatsd.configure do |config|
    config.pod_name = ENV.fetch('HOSTNAME')
    # Extract deployment name from pod name
    config.statsd_grouping = ENV.fetch('HOSTNAME').sub(/\-[a-z0-9]+\-[a-z0-9]{5}$/, '')
    config.statsd_host = ENV.fetch('DD_HOST')
    config.statsd_port = ENV.fetch('DD_STATSD_PORT')
  end
```

#### Configure metric types
By default, the following metrics is gathered: 

* `workers`
* `booted_workers`
* `old_workers`
* `running`
* `backlog`
* `max_threads`
* `requests_count`
* `percent_busy` -- how much of the pool capacity is taken already

All is collected with `:gauge` type, except `:percent_busy`, which is collected
with `:histogram` type. Via advanced configuration you can change it like this:

```ruby
  ::PumaStatsd.configure do |config|
    config.metrics[:backlog] = :histogram # :count, :gauge and :histogram is supported
    config.metrics.delete(:old_workers)
  end
```

Stats is calculated as a method called on `PumaStatsd::PumaStats` instance. See
source code for more details.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/yob/puma-plugin-statsd.

### Tests

This gem uses MiniTest for unit testing.

Run tests with `rake test`.

## Testing the data being sent to statsd

Start a pretend statsd server that listens for UDP packets on port 8125.

If you've installed the gem in your app:

    # only need to install the binstub once
    bundle binstubs puma-plugin-statsd
    ./bin/statsd-to-stdout

If you are developing/testing this gem locally:

    ./bin/statsd-to-stdout

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
