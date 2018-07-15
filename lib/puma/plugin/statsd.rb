# coding: utf-8, frozen_string_literal: true

require "json"
require 'socket'
require "puma"
require "puma/plugin"


Puma::Plugin.create do
  class Statsd
    ENV_NAME = "STATSD_HOST"
    STATSD_PORT = 8125
    STATSD_TYPES = { count: 'c', gauge: 'g' }
    REPORTING_PAUSE_SECONDS = 2

    attr_reader :host

    def initialize
      @host = ENV.fetch(ENV_NAME, nil)
    end

    def enabled?
      !host
    end

    def send(metric_name:, value:, type:)
      data = "#{metric_name}:#{value}|#{STATSD_TYPES.fetch(type)}"

      UDPSocket.new.send(data, 0, host, STATSD_PORT)
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

  # Puma creates the plugin when encountering `plugin` in the config.
  def initialize(loader)
    @loader = loader
  end

  # We can start doing something when we have a launcher:
  def start(launcher)
    @launcher = launcher

    @statsd = Statsd.new
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

  def stats
    PumaStats.new(fetch_stats)
  end

  # Send data to statsd every few seconds
  def stats_loop
    sleep 5
    loop do
      @launcher.events.debug "statsd: notify statsd"
      begin
        @statsd.send(metric_name: "puma.workers", value: stats.workers, type: :gauge)
        @statsd.send(metric_name: "puma.booted_workers", value: stats.booted_workers, type: :gauge)
        @statsd.send(metric_name: "puma.running", value: stats.running, type: :gauge)
        @statsd.send(metric_name: "puma.backlog", value: stats.backlog, type: :gauge)
        @statsd.send(metric_name: "puma.pool_capacity", value: stats.pool_capacity, type: :gauge)
        @statsd.send(metric_name: "puma.max_threads", value: stats.max_threads, type: :gauge)
      rescue StandardError => e
        @launcher.events.error "! statsd: notify stats failed:\n  #{e.to_s}\n  #{e.backtrace.join("\n    ")}"
      ensure
        sleep REPORTING_PAUSE_SECONDS
      end
    end
  end

end
