# Puma Statsd Plugin

EverFi fork of the puma statsd plugin. Sends key [Puma][puma] metrics to [statsd][statsd].

Metrics:

* puma.workers - number of workers (for clustered mode)
* puma.booted_workers - number of workers booted (for clustered mode)
* puma.running - number of threads spawned currently
* puma.backlog - number of requests waiting to be picked up by a thread
* puma.pool_capacity - number of available threads to process requests
* puma.max_threads - maximum number of threads that can be spawned
* puma.percent_busy - percentage of max_threads that are currently processing requests
* puma.old_workers
* puma.requests_count

When running puma in clustered mode, stats will be totals across all of the workers running

In our case, these will be sent to datadog and tagged with:

* pod_name (e.g. dev-adminifi-web-cff64b8f9-6mlsp)
* grouping (e.g. dev-adminifi-web)

## Installation

Add this gem to your Gemfile under the EverFi gemfury source:

```ruby
source 'https://<your app token>@gem.fury.io/everfi/' do

  gem "puma-plugin-statsd"

end
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


Add the following to your config/puma.rb:


```ruby
# The PERFTOOLS_DATADOG_* vars are used by the foundry-perftools
# gem to connect to our local datadog statsd service.
#
# Feel free to use different vars if you want to.
#
# We are checking for KUBERNETES_SERVICE_HOST so this only runs
# when deployed to our kubernetes clusters. Change this if you
# want to run it locally.
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


## Development

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

### Tests

This gem uses MiniTest for unit testing

Run tests with `rake test`

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
