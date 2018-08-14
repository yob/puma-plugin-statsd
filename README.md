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

Ensure you have an environment variable set that points to a statsd host, then boot your puma app as usual

```
STATSD_HOST=127.0.0.1 bundle exec puma
```

```
STATSD_HOST=127.0.0.1 MY_POD_NAME=foo bundle exec puma
```

### Datadog Integration

metric tags are a non-standard addition to the statsd protocol, supported by
the datadog "dogstatsd" server.

Should you be reporting the puma metrics to a dogstatsd server, you can set
tags via the following two environment variables.

`MY_POD_NAME` adds a `pod_name` tag to the metrics. The `MY_POD_NAME`
environment variable is recommended in th datadog kubernetes setup
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

`STATSD_GROUPING` adds a `grouping` tag to the metrics, with a value equal to
the environment variable value. This is particularly helpful in a kubernetes
deployment where each pod has a unique name but you want the option to group
metrics across all pods in a deployment. Setting this on the pods in a
deployment might look something like:

```yaml
env:
  - name: STATSD_GROUPING
    value: deployment-foo
```

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/yob/puma-plugin-statsd.

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
