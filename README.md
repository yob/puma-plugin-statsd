# Puma Systemd Plugin

[Puma][puma] integration with [systemd](systemd) for better daemonising under
modern Linux systemds: notify, status, watchdog.

* Notify systemd when puma has booted and is [ready to handle requests][ready]
* Publish puma stats as systemd [service status][status] for a quick overview
* Use the [watchdog][systemd-watchdog] to make sure your puma processes are
  healthy and haven't locked up or run out of memory

Puma already natively supports [socket activation][socket-activation].

  [puma]: https://github.com/puma/puma
  [systemd]: https://www.freedesktop.org/wiki/Software/systemd/
  [ready]: https://www.freedesktop.org/software/systemd/man/sd_notify.html#READY=1
  [status]: https://www.freedesktop.org/software/systemd/man/sd_notify.html#STATUS=...
  [watchdog]: https://www.freedesktop.org/software/systemd/man/sd_notify.html#WATCHDOG=1
  [socket-activation]: http://github.com/puma/puma/blob/master/docs/systemd.md#socket-activation

## Installation

Add this gem to your Gemfile with puma and then bundle:

```ruby
gem "puma"
gem "puma-plugin-systemd"
```

Add it to your puma config:

```ruby
# config/puma.rb

bind "http://127.0.0.1:9292"

workers 2
threads 8, 16

plugin :systemd
```

## Usage

### Notify

Make sure puma is being started using a [systemd service unit][systemd-service]
with `Type=notify`, something like:

```ini
# puma.service
[Service]
Type=notify
User=puma
WorkingDirectory=/app
ExecStart=/app/bin/puma -C config/puma.rb -e production
ExecReload=/bin/kill -USR1 $MAINPID
ExecRestart=/bin/kill -USR2 $MAINPID
Restart=always
KillMode=mixed
```

  [systemd-service]: https://www.freedesktop.org/software/systemd/man/systemd.service.html

### Status

Running in notify mode as above should just start publishing puma stats as
systemd status. Running `systemctl status puma.service` or similar should
result in a Status line in your status output:

```
app@web:~$ sudo systemctl status puma.service
● puma.service - puma
   Loaded: loaded (/etc/systemd/system/puma.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2016-10-24 00:26:55 UTC; 5s ago
 Main PID: 32234 (ruby2.3)
   Status: "puma 3.6.0 cluster: 2/2 workers: 16 threads, 0 backlog"
    Tasks: 10
   Memory: 167.9M
      CPU: 7.150s
   CGroup: /system.slice/puma.service
           ├─32234 puma 3.6.0 (unix:///app/tmp/sockets/puma.sock?backlog=1024) [app]
           ├─32251 puma: cluster worker 0: 32234 [app]
           └─32253 puma: cluster worker 1: 32234 [app]

Oct 24 00:26:10 web systemd[30762]: puma.service: Executing: /app/bin/puma -C config/puma.rb -e production
Oct 24 00:54:58 web puma[32234]: [32234] Puma starting in cluster mode...
Oct 24 00:54:58 web puma[32234]: [32234] * Version 3.6.0 (ruby 2.3.1-p112), codename: Sleepy Sunday Serenity
Oct 24 00:54:58 web puma[32234]: [32234] * Min threads: 8, max threads: 64
Oct 24 00:26:55 web puma[32234]: [32234] * Environment: production
Oct 24 00:26:55 web puma[32234]: [32234] * Process workers: 2
Oct 24 00:26:55 web puma[32234]: [32234] * Phased restart available
Oct 24 00:26:55 web puma[32234]: [32234] * Listening on unix:///app/tmp/sockets/puma.sock?backlog=1024
Oct 24 00:26:55 web puma[32234]: [32234] Use Ctrl-C to stop
Oct 24 00:26:55 web puma[32234]: [32234] * systemd: notify ready
Oct 24 00:26:55 web puma[32234]: [32251] + Gemfile in context: /app/Gemfile
Oct 24 00:26:55 web systemd[1]: Started puma.
Oct 24 00:26:55 web puma[32234]: [32234] * systemd: watchdog detected (30000000usec)
Oct 24 00:26:55 web puma[32234]: [32253] + Gemfile in context: /app/Gemfile
```

### Watchdog

Adding a `WatchdogSec=30` or similar to your systemd service file will tell
puma systemd to ping systemd at half the specified interval to ensure the
service is running and healthy.

## Development

After checking out the repo, run `script/setup` to install dependencies. Then,
run `rake test` to run the tests. You can also run `script/console` for an
interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/sj26/puma-plugin-systemd.

## License

The gem is available as open source under the terms of the [MIT License][license].

  [license]: http://opensource.org/licenses/MIT
