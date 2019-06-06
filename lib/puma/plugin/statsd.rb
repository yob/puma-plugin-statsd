# coding: utf-8, frozen_string_literal: true
require "json"
require "puma"
require "puma/plugin"
require 'socket'

class StatsdConnector
  ENV_NAME = "STATSD_HOST"
  STATSD_TYPES = { count: 'c', gauge: 'g' }

  attr_reader :host, :port

  def initialize
    @host = ENV.fetch(ENV_NAME, nil)
    @port = ENV.fetch("STATSD_PORT", 8125)
  end

  def enabled?
    !!host
  end

  def send(metric_name:, value:, type:, tags: {})
    data = "#{metric_name}:#{value}|#{STATSD_TYPES.fetch(type)}"
    if tags.any?
      tag_str = tags.map { |k,v| "#{k}:#{v}" }.join(",")
      data = "#{data}|##{tag_str}"
    end

    UDPSocket.new.send(data, 0, host, port)
  end
end

# Wrap puma's stats in a safe API
class PumaStats
  def initialize(stats)
    @stats = stats
  end

  def clustered?
    @stats.has_key? "workers"
  end

  def workers
    @stats.fetch("workers", 1)
  end

  def booted_workers
    @stats.fetch("booted_workers", 1)
  end

  def running
    if clustered?
      @stats["worker_status"].map { |s| s["last_status"].fetch("running", 0) }.inject(0, &:+)
    else
      @stats.fetch("running", 0)
    end
  end

  def backlog
    if clustered?
      @stats["worker_status"].map { |s| s["last_status"].fetch("backlog", 0) }.inject(0, &:+)
    else
      @stats.fetch("backlog", 0)
    end
  end

  def pool_capacity
    if clustered?
      @stats["worker_status"].map { |s| s["last_status"].fetch("pool_capacity", 0) }.inject(0, &:+)
    else
      @stats.fetch("pool_capacity", 0)
    end
  end

  def max_threads
    if clustered?
      @stats["worker_status"].map { |s| s["last_status"].fetch("max_threads", 0) }.inject(0, &:+)
    else
      @stats.fetch("max_threads", 0)
    end
  end
end

Puma::Plugin.create do
  # Puma creates the plugin when encountering `plugin` in the config.
  def initialize(loader)
    @loader = loader
  end

  # We can start doing something when we have a launcher:
  def start(launcher)
    @launcher = launcher

    @statsd = ::StatsdConnector.new
    if @statsd.enabled?
      @launcher.events.debug "statsd: enabled (host: #{@statsd.host})"
      register_hooks
    else
      @launcher.events.debug "statsd: not enabled (no #{Statsd::ENV_NAME} env var found)"
    end
  end

  private

  def register_hooks
    in_background(&method(:stats_loop))
  end

  def fetch_stats
    JSON.parse(Puma.stats)
  end

  def tags
    tags = {}
    if ENV.has_key?("MY_POD_NAME")
      tags[:pod_name] = ENV.fetch("MY_POD_NAME", "no_pod")
    end
    if ENV.has_key?("STATSD_GROUPING")
      tags[:grouping] = ENV.fetch("STATSD_GROUPING", "no-group")
    end
    tags
  end

  # Send data to statsd every few seconds
  def stats_loop
    sleep 5
    loop do
      @launcher.events.debug "statsd: notify statsd"
      begin
        stats = ::PumaStats.new(fetch_stats)
        @statsd.send(metric_name: "puma.workers", value: stats.workers, type: :gauge, tags: tags)
        @statsd.send(metric_name: "puma.booted_workers", value: stats.booted_workers, type: :gauge, tags: tags)
        @statsd.send(metric_name: "puma.running", value: stats.running, type: :gauge, tags: tags)
        @statsd.send(metric_name: "puma.backlog", value: stats.backlog, type: :gauge, tags: tags)
        @statsd.send(metric_name: "puma.pool_capacity", value: stats.pool_capacity, type: :gauge, tags: tags)
        @statsd.send(metric_name: "puma.max_threads", value: stats.max_threads, type: :gauge, tags: tags)
      rescue StandardError => e
        @launcher.events.error "! statsd: notify stats failed:\n  #{e.to_s}\n  #{e.backtrace.join("\n    ")}"
      ensure
        sleep 2
      end
    end
  end
end
