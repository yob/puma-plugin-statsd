# CHANGELOG

## 2.0.0 2021-07-27

* Require puma 5 or better
* Split DD_TAGS environment variable by commas or spaces (PR #[31](https://github.com/yob/puma-plugin-statsd/pull/31))
* Gracefully handle unexpecte errors when submitting to statsd (like DNS resolution failures) (PR #[35](https://github.com/yob/puma-plugin-statsd/pull/35))

## 1.2.1 2021-01-11

* Remove json from the gemspec

## 1.2.0 2021-01-07

* New metrics: old_workers (PR #[21](https://github.com/yob/puma-plugin-statsd/pull/21)) and requests_count (PR #[28](https://github.com/yob/puma-plugin-statsd/pull/28))
* Require json at runtime to be extra sure we don't load the wrong version before bundler has initialised the LOAD_PATH

## 1.1.0 2021-01-03

* Assume localhost for statsd host (PR #[20](https://github.com/yob/puma-plugin-statsd/pull/20))

## 1.0.0 2020-11-03

* Added option to specify arbitrary datadog tags (PR #[18](https://github.com/yob/puma-plugin-statsd/pull/18))

## 0.3.0 2020-09-24

* Support puma 5.x

## 0.2.0 2020-02-29

* Added option to prefix stats metric (via STATSD_METRIC_PREFIX env var)

## 0.1.0 2019-07-06

* The statsd port is now configurable
* Support puma 4.x

## 0.0.1 2018-07-17

Initial Release
