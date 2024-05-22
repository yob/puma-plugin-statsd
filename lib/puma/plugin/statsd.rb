# coding: utf-8
# frozen_string_literal: true
require "puma"
require "puma/plugin"
require 'socket'

class StatsdConnector
  ENV_NAME = "STATSD_HOST"
  STATSD_TYPES = { count: 'c', gauge: 'g' }
  METRIC_DELIMETER = "."

  attr_reader :host, :port

  def initialize
    @host = ENV.fetch(ENV_NAME, "127.0.0.1")
    @port = ENV.fetch("STATSD_PORT", 8125)
    @socket_path = ENV.fetch("STATSD_SOCKET_PATH", nil)
  end

  def send(metric_name:, value:, type:, tags: nil)
    data = "#{metric_name}:#{value}|#{STATSD_TYPES.fetch(type)}"
    data = "#{data}|##{tags}" unless tags.nil?

    if @socket_path
      socket = Socket.new(Socket::AF_UNIX, Socket::SOCK_DGRAM)
      socket.connect(Socket.pack_sockaddr_un(@socket_path))
      socket.sendmsg_nonblock(data)
    else
      address_family, _, _ = Socket.getaddrinfo(host, port)[0]
      socket = UDPSocket.new(Socket.const_get(address_family))
      socket.send(data, 0, host, port)
    end
  ensure
    socket.close
  end
end

# Wrap puma's stats in a safe API
class PumaStats
  def initialize(stats, previous_requests_count = 0)
    @stats = stats
    @previous_requests_count = previous_requests_count
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

  def old_workers
    @stats.fetch(:old_workers, 0)
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

  def requests_count
    if clustered?
      @stats[:worker_status].map { |s| s[:last_status].fetch(:requests_count, 0) }.inject(0, &:+)
    else
      @stats.fetch(:requests_count, 0)
    end
  end

  def percent_busy
    (1 - (pool_capacity / max_threads.to_f)) * 100
  end

  def requests_delta
    requests_count - @previous_requests_count
  end
end

Puma::Plugin.create do
  # We can start doing something when we have a launcher:
  def start(launcher)
    @launcher = launcher
    @log_writer =
      if Gem::Version.new(Puma::Const::PUMA_VERSION) >= Gem::Version.new(6)
        @launcher.log_writer
      else
        @launcher.events
      end

    @statsd = ::StatsdConnector.new
    @interval_seconds = ENV.fetch("STATSD_INTERVAL_SECONDS", "2").to_f
    @log_writer.debug "statsd: enabled (host: #{@statsd.host}, interval: #{@interval})"

    # Fetch global metric prefix from env variable
    @metric_prefix = ENV.fetch("STATSD_METRIC_PREFIX", nil)
    if @metric_prefix && !@metric_prefix.end_with?(::StatsdConnector::METRIC_DELIMETER)
      @metric_prefix += ::StatsdConnector::METRIC_DELIMETER
    end

    register_hooks
  end

  private

  def register_hooks
    in_background(&method(:stats_loop))
  end

  def environment_variable_tags
    # Tags are separated by spaces, and while they are normally a tag and
    # value separated by a ':', they can also just be tagged without any
    # associated value.
    #
    # Examples: simple-tag-0 tag-key-1:tag-value-1
    #
    tags = []

    if ENV.has_key?("MY_POD_NAME")
      tags << "pod_name:#{ENV['MY_POD_NAME']}"
    end

    if ENV.has_key?("STATSD_GROUPING")
      tags << "grouping:#{ENV['STATSD_GROUPING']}"
    end

    # Standardised datadog tag attributes, so that we can share the metric
    # tags with the application running
    #
    # https://docs.datadoghq.com/agent/docker/?tab=standard#global-options
    #
    if ENV.has_key?("DD_TAGS")
      ENV["DD_TAGS"].split(/\s+|,/).each do |t|
        tags << t
      end
    end

    # Support the Unified Service Tagging from Datadog, so that we can share
    # the metric tags with the application running
    #
    # https://docs.datadoghq.com/getting_started/tagging/unified_service_tagging
    if ENV.has_key?("DD_ENV")
      tags << "env:#{ENV["DD_ENV"]}"
    end

    if ENV.has_key?("DD_SERVICE")
      tags << "service:#{ENV["DD_SERVICE"]}"
    end

    if ENV.has_key?("DD_VERSION")
      tags << "version:#{ENV["DD_VERSION"]}"
    end

    # Support the origin detection over UDP from Datadog, it allows DogStatsD
    # to detect where the container metrics come from, and tag metrics automatically.
    #
    # https://docs.datadoghq.com/developers/dogstatsd/?tab=kubernetes#origin-detection-over-udp
    if ENV.has_key?("DD_ENTITY_ID")
      tags << "dd.internal.entity_id:#{ENV["DD_ENTITY_ID"]}"
    end

    # Return nil if we have no environment variable tags. This way we don't
    # send an unnecessary '|' on the end of each stat
    return nil if tags.empty?

    tags.join(",")
  end

  def prefixed_metric_name(puma_metric)
    "#{@metric_prefix}#{puma_metric}"
  end

  # Send data to statsd every few seconds
  def stats_loop
    tags = environment_variable_tags
    previous_requests_count = 0

    sleep 5
    loop do
      @log_writer.debug "statsd: notify statsd"
      begin
        stats = ::PumaStats.new(Puma.stats_hash, previous_requests_count)
        previous_requests_count = stats.requests_count
        @statsd.send(metric_name: prefixed_metric_name("puma.workers"), value: stats.workers, type: :gauge, tags: tags)
        @statsd.send(metric_name: prefixed_metric_name("puma.booted_workers"), value: stats.booted_workers, type: :gauge, tags: tags)
        @statsd.send(metric_name: prefixed_metric_name("puma.old_workers"), value: stats.old_workers, type: :gauge, tags: tags)
        @statsd.send(metric_name: prefixed_metric_name("puma.running"), value: stats.running, type: :gauge, tags: tags)
        @statsd.send(metric_name: prefixed_metric_name("puma.backlog"), value: stats.backlog, type: :gauge, tags: tags)
        @statsd.send(metric_name: prefixed_metric_name("puma.pool_capacity"), value: stats.pool_capacity, type: :gauge, tags: tags)
        @statsd.send(metric_name: prefixed_metric_name("puma.max_threads"), value: stats.max_threads, type: :gauge, tags: tags)
        @statsd.send(metric_name: prefixed_metric_name("puma.percent_busy"), value: stats.percent_busy, type: :gauge, tags: tags)
        @statsd.send(metric_name: prefixed_metric_name("puma.requests_count"), value: stats.requests_count, type: :gauge, tags: tags)
        @statsd.send(metric_name: prefixed_metric_name("puma.requests"), value: stats.requests_delta, type: :count, tags: tags)
      rescue StandardError => e
        @log_writer.unknown_error e, nil, "! statsd: notify stats failed"
      ensure
        sleep @interval_seconds
      end
    end
  end
end
