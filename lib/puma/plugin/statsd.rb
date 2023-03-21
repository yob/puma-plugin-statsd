# coding: utf-8
# frozen_string_literal: true
require 'puma'
require 'puma/plugin'
require 'socket'
require 'ostruct'

module PumaStatsd
  def self.config
    @config ||= OpenStruct.new({
      statsd_host: ENV.fetch(StatsdConnector::ENV_NAME, '127.0.0.1'),
      statsd_port: ENV.fetch('STATSD_PORT', 8125),
      statsd_socket_path: ENV.fetch('STATSD_SOCKET_PATH', nil),
      pod_name: ENV.fetch('MY_POD_NAME', nil),
      statsd_grouping: ENV.fetch('STATSD_GROUPING', nil),
      statsd_sleep_interval: ENV.fetch('STATSD_SLEEP_INTERVAL', '2'),
      metric_prefix: ENV.fetch('STATSD_METRIC_PREFIX', nil),
      dd_tags: ENV.fetch('DD_TAGS', nil),
      dd_env: ENV.fetch('DD_ENV', nil),
      dd_service: ENV.fetch('DD_SERVICE', nil),
      dd_version: ENV.fetch('DD_VERSION', nil),
      dd_entity_id: ENV.fetch('DD_ENTITY_ID', nil)
    })
  end

  def self.configure
    yield config
  end

  def self.reset_config
    @config = nil
  end
end

class StatsdConnector
  ENV_NAME = 'STATSD_HOST'
  STATSD_TYPES = { count: 'c', gauge: 'g' }
  METRIC_DELIMETER = '.'

  attr_reader :host, :port

  def initialize
    @host = ::PumaStatsd.config.statsd_host
    @port = ::PumaStatsd.config.statsd_port
    @socket_path = ::PumaStatsd.config.statsd_socket_path
  end

  def send(metric_name:, value:, type:, tags: nil)
    data = "#{metric_name}:#{value}|#{STATSD_TYPES.fetch(type)}"
    data = "#{data}|##{tags}" unless tags.nil?

    if @socket_path
      socket = Socket.new(Socket::AF_UNIX, Socket::SOCK_DGRAM)
      socket.connect(Socket.pack_sockaddr_un(@socket_path))
      socket.sendmsg_nonblock(data)
    else
      socket = udp_socket
      socket.send(data, 0, host, port)
    end
  ensure
    socket.close
  end

  private

  def udp_socket
    UDPSocket.new
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
    @log_writer.debug "statsd: enabled (host: #{@statsd.host})"

    # Fetch global metric prefix from env variable
    @metric_prefix = PumaStatsd.config.metric_prefix
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

    if ::PumaStatsd.config.pod_name
      tags << "pod_name:#{::PumaStatsd.config.pod_name}"
    end

    if ::PumaStatsd.config.statsd_grouping
      tags << "grouping:#{::PumaStatsd.config.statsd_grouping}"
    end

    # Standardised datadog tag attributes, so that we can share the metric
    # tags with the application running
    #
    # https://docs.datadoghq.com/agent/docker/?tab=standard#global-options
    #
    if ::PumaStatsd.config.dd_tags
      ::PumaStatsd.config.dd_tags.split(/\s+|,/).each do |t|
        tags << t
      end
    end

    # Support the Unified Service Tagging from Datadog, so that we can share
    # the metric tags with the application running
    #
    # https://docs.datadoghq.com/getting_started/tagging/unified_service_tagging
    if ::PumaStatsd.config.dd_env
      tags << "env:#{::PumaStatsd.config.dd_env}"
    end

    if ::PumaStatsd.config.dd_service
      tags << "service:#{::PumaStatsd.config.dd_service}"
    end

    if ::PumaStatsd.config.dd_version
      tags << "version:#{::PumaStatsd.config.dd_version}"
    end

    # Support the origin detection over UDP from Datadog, it allows DogStatsD
    # to detect where the container metrics come from, and tag metrics automatically.
    #
    # https://docs.datadoghq.com/developers/dogstatsd/?tab=kubernetes#origin-detection-over-udp
    if ::PumaStatsd.config.dd_entity_id
      tags << "dd.internal.entity_id:#{::PumaStatsd.config.dd_entity_id}"
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

    sleep 5
    loop do
      @log_writer.debug "statsd: notify statsd"
      begin
        stats = ::PumaStats.new(Puma.stats_hash)
        @statsd.send(metric_name: prefixed_metric_name('puma.workers'), value: stats.workers, type: :gauge, tags: tags)
        @statsd.send(metric_name: prefixed_metric_name('puma.booted_workers'), value: stats.booted_workers, type: :gauge, tags: tags)
        @statsd.send(metric_name: prefixed_metric_name('puma.old_workers'), value: stats.old_workers, type: :gauge, tags: tags)
        @statsd.send(metric_name: prefixed_metric_name('puma.running'), value: stats.running, type: :gauge, tags: tags)
        @statsd.send(metric_name: prefixed_metric_name('puma.backlog'), value: stats.backlog, type: :gauge, tags: tags)
        @statsd.send(metric_name: prefixed_metric_name('puma.pool_capacity'), value: stats.pool_capacity, type: :gauge, tags: tags)
        @statsd.send(metric_name: prefixed_metric_name('puma.max_threads'), value: stats.max_threads, type: :gauge, tags: tags)
        @statsd.send(metric_name: prefixed_metric_name('puma.requests_count'), value: stats.requests_count, type: :gauge, tags: tags)
      rescue StandardError => e
        @log_writer.unknown_error e, nil, "! statsd: notify stats failed"
      ensure
        sleep ::PumaStatsd.config.statsd_sleep_interval.to_f
      end
    end
  end
end
