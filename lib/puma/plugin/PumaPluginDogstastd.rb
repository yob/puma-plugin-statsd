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
    dogstatsd_client = get_dogstatsd_client(launcher)
    raise 'PumaPluginDogstastd: Dogstatsd client not found' if dogstatsd_client.nil?

    clustered = launcher.send(:clustered?) # See https://github.com/puma/puma/blob/master/lib/puma/launcher.rb#L285

    dogstatsd_client.event("PumaPluginDogstastd enabled", "Cluster mode: #{clustered}")
    launcher.events.debug "PumaPluginDatadogStastd - enabled. Cluster mode: #{clustered}"

    in_background do
      sleep 5
      loop do
        begin
          stats = Puma.stats
          launcher.events.debug "PumaPluginDatadogStastd - notify stats: #{stats}"

          parsed_stats = JSON.parse(stats)
          dogstatsd_client.count('puma.workers', parsed_stats.fetch('workers', 1))
          dogstatsd_client.count('puma.booted_workers', parsed_stats.fetch('booted_workers', 1))
          dogstatsd_client.count('puma.running', count_value_for_key(clustered, parsed_stats, 'running'))
          dogstatsd_client.count('puma.backlog', count_value_for_key(clustered, parsed_stats, 'backlog'))
          dogstatsd_client.count('puma.pool_capacity', count_value_for_key(clustered, parsed_stats, 'pool_capacity'))
          dogstatsd_client.count('puma.max_threads', count_value_for_key(clustered, parsed_stats, 'max_threads'))
        rescue StandardError => e
          launcher.events.error "PumaPluginDatadogStastd - notify stats failed:\n  #{e.to_s}\n  #{e.backtrace.join("\n    ")}"
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

  def get_dogstatsd_client(launcher)
    launcher.instance_variable_get(:@options)[PumaPluginDogstastd::KEY]
  end

end
