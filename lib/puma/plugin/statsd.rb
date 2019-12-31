# coding: utf-8, frozen_string_literal: true
require "json"
require "puma"
require "puma/plugin"
require 'socket'

class StatsdConnector
  def initialize
    @data = []
  end

  def enabled?
    true
  end

  def send(metric_name:, value:, type:, tags: {})
    @data << "#{type}##{metric_name}=#{value}"
  end

  def submit(&block)
    block.call(self)
    STDOUT.puts @data.join(" ")
    @data.clear
  end
end

# Wrap puma's stats in a safe API
class PumaStats
  def initialize(stats)
    @stats = stats
  end

  def clustered?
    @stats.has_key?(:workers)
  end

  def workers
    @stats.fetch(:workers, 1)
  end

  def booted_workers
    @stats.fetch(:booted_workers, 1)
  end

  def running
    if clustered?
      @stats[:worker_status].map { |s| s[:last_status].fetch(:running, 0) }.inject(0, &:+)
    else
      @stats.fetch(:running, 0)
    end
  end

  def backlog
    if clustered?
      @stats[:worker_status].map { |s| s[:last_status].fetch(:backlog, 0) }.inject(0, &:+)
    else
      @stats.fetch(:backlog, 0)
    end
  end

  def pool_capacity
    if clustered?
      @stats[:worker_status].map { |s| s[:last_status].fetch(:pool_capacity, 0) }.inject(0, &:+)
    else
      @stats.fetch(:pool_capacity, 0)
    end
  end

  def max_threads
    if clustered?
      @stats[:worker_status].map { |s| s[:last_status].fetch(:max_threads, 0) }.inject(0, &:+)
    else
      @stats.fetch(:max_threads, 0)
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
      @launcher.events.debug "statsd: enabled"
      register_hooks
    else
      @launcher.events.debug "statsd: not enabled (no #{StatsdConnector::ENV_NAME} env var found)"
    end
  end

  private

  def register_hooks
    in_background(&method(:stats_loop))
  end

  def fetch_stats
    JSON.parse(Puma.stats, symbolize_names: true)
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
    sleep 30
    loop do
      @launcher.events.debug "statsd: notify statsd"
      begin
        stats = ::PumaStats.new(fetch_stats)
        @statsd.submit do |s|
          s.send(metric_name: "puma.workers", value: stats.workers, type: :measure, tags: tags)
          s.send(metric_name: "puma.booted_workers", value: stats.booted_workers, type: :measure, tags: tags)
          s.send(metric_name: "puma.running", value: stats.running, type: :measure, tags: tags)
          s.send(metric_name: "puma.backlog", value: stats.backlog, type: :measure, tags: tags)
          s.send(metric_name: "puma.pool_capacity", value: stats.pool_capacity, type: :measure, tags: tags)
          s.send(metric_name: "puma.max_threads", value: stats.max_threads, type: :measure, tags: tags)
        end
      rescue StandardError => e
        @launcher.events.error "! statsd: notify stats failed:\n  #{e.to_s}\n  #{e.backtrace.join("\n    ")}"
      ensure
        sleep 2
      end
    end
  end
end
