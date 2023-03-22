require 'test_helper'

class PumaStatsTest < MiniTest::Test
  extend Minitest::Spec::DSL

  let(:cluster_statistics) do
    {
        workers: 2,
        booted_workers: 2,
        worker_status: [worker_statistics,worker_statistics].map {|w| {last_status: w}}
    }
  end

  let(:worker_statistics) do
    {
        running: 1,
        backlog: 5,
        pool_capacity: 2,
        max_threads: 3
    }
  end

  let(:cluster_stats) { PumaStats.new(cluster_statistics) }
  let(:worker_stats) { PumaStats.new(worker_statistics) }

  def setup
    # Do nothing
  end

  def test_clustered?
    assert cluster_stats.clustered?
    refute worker_stats.clustered?
  end

  def test_workers
    assert_equal 2,cluster_stats.workers
    assert_equal 1,worker_stats.workers
  end

  def test_booted_workers
    assert_equal 2,cluster_stats.booted_workers
    assert_equal 1,worker_stats.booted_workers
  end

  def test_running
    assert_equal 2, cluster_stats.running
    assert_equal 1, worker_stats.running
  end

  def test_backlog
    assert_equal 10, cluster_stats.backlog
    assert_equal 5, worker_stats.backlog
  end

  def test_pool_capacity
    assert_equal 4, cluster_stats.pool_capacity
    assert_equal 2, worker_stats.pool_capacity
  end

  def test_max_threads
    assert_equal 6, cluster_stats.max_threads
    assert_equal 3, worker_stats.max_threads
  end

  def test_percent_busy
    assert_equal 33, cluster_stats.percent_busy
    assert_equal 33, worker_stats.percent_busy
  end

  def test_percent_busy_zero_max_threads
    ws = worker_statistics
    ws[:max_threads] = 0
    assert_equal 0, PumaStats.new(ws).percent_busy
  end
end
