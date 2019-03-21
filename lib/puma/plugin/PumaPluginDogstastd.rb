# coding: utf-8, frozen_string_literal: true

require 'json'
require 'puma'
require 'puma/plugin'

module PumaPluginDogstastd

  KEY = :puma_plugin_datadog_statsd_client

  def activate(puma_config, datadog_statsd_client)
    raise "'puma_config' should not be nil" if puma_config.nil?
    raise "'datadog_statsd_client' should not be nil" if datadog_statsd_client.nil?

    puma_config.inject { @options[KEY] = datadog_statsd_client }
    puma_config.plugin(:PumaPluginDogstastd)
  end
  module_function :activate

end

Puma::Plugin.create do

  def start(launcher)
    dogstatsd_client = PumaPluginDogstastd.get_dogstatsd_client(launcher)

    clustered = launcher.send(:clustered?) # See https://github.com/puma/puma/blob/master/lib/puma/launcher.rb#L285

    launcher.events.debug "PumaPluginDatadogStastd: enabled"

    in_background do
      sleep 5
      loop do
        launcher.events.debug 'PumaPluginDatadogStastd: notify statsd'
        begin
          stats = fetch_stats

          dogstatsd_client.gauge('puma.workers', stats.fetch('workers', 1))
          dogstatsd_client.gauge('puma.booted_workers', stats.fetch('booted_workers', 1))
          dogstatsd_client.gauge('puma.running', count_value_for_key(clustered, stats, 'running'))
          dogstatsd_client.gauge('puma.backlog', count_value_for_key(clustered, stats, 'backlog'))
          dogstatsd_client.gauge('puma.pool_capacity', count_value_for_key(clustered, stats, 'pool_capacity'))
          dogstatsd_client.gauge('puma.max_threads', count_value_for_key(clustered, stats, 'max_threads'))
        rescue StandardError => e
          launcher.events.error "PumaPluginDatadogStastd: notify stats failed:\n  #{e.to_s}\n  #{e.backtrace.join("\n    ")}"
        ensure
          sleep 2
        end
      end
    end
  end

  private

  def count_value_for_key(clustered, stats, key)
    if clustered
      stats['worker_status'].reduce(0) { |acc, s| acc + s['last_status'].fetch(key, 0) }
    else
      stats.fetch(key, 0)
    end
  end

  def fetch_stats
    JSON.parse(Puma.stats)
  end

  def get_dogstatsd_client(launcher)
    launcher.instance_variable_get(:@options)[PumaPluginDogstastd::KEY]
  end

end
