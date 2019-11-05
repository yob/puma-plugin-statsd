require 'test_helper'

class ConfigTest < MiniTest::Test
  def setup
    # Do nothing
  end

  def teardown
    PumaStatsd.reset_config
    %w[STATSD_HOST STATSD_PORT MY_POD_NAME STATSD_GROUPING].each {|var| ENV.delete var }
  end

  def test_config
    assert_kind_of OpenStruct, PumaStatsd.config
  end

  def test_config_defaults
    assert_equal '127.0.0.1', PumaStatsd.config.statsd_host
    assert_equal '8125'     , PumaStatsd.config.statsd_port
    assert_nil       PumaStatsd.config.pod_name
    assert_nil       PumaStatsd.config.statsd_grouping
  end

  def test_config_from_default_env
    ENV['STATSD_HOST']      = 'test.com'
    ENV['STATSD_PORT']      = '1234'
    ENV['MY_POD_NAME']      = 'sample_pod'
    ENV['STATSD_GROUPING']  = 'sample_group'

    assert_equal 'test.com'     , PumaStatsd.config.statsd_host
    assert_equal '1234'         , PumaStatsd.config.statsd_port
    assert_equal 'sample_pod'   , PumaStatsd.config.pod_name
    assert_equal 'sample_group' , PumaStatsd.config.statsd_grouping
  end

  def test_configure_block
    PumaStatsd.configure do |config|
      config.statsd_host = 'test.com'
      config.statsd_port = '1234'
      config.pod_name = 'sample_pod'
      config.statsd_grouping = 'sample_group'
    end

    assert_equal 'test.com'     , PumaStatsd.config.statsd_host
    assert_equal '1234'         , PumaStatsd.config.statsd_port
    assert_equal 'sample_pod'   , PumaStatsd.config.pod_name
    assert_equal 'sample_group' , PumaStatsd.config.statsd_grouping
  end

  def test_configure_block_takes_precedence

    ENV['STATSD_HOST']      = 'bad.com'
    ENV['STATSD_PORT']      = '9876'
    ENV['MY_POD_NAME']      = 'bad_pod'
    ENV['STATSD_GROUPING']  = 'bad_group'

    PumaStatsd.configure do |config|
      config.statsd_host = 'test.com'
      config.statsd_port = '1234'
      config.pod_name = 'sample_pod'
      config.statsd_grouping = 'sample_group'
    end

    assert_equal 'test.com'     , PumaStatsd.config.statsd_host
    assert_equal '1234'         , PumaStatsd.config.statsd_port
    assert_equal 'sample_pod'   , PumaStatsd.config.pod_name
    assert_equal 'sample_group' , PumaStatsd.config.statsd_grouping
  end
end
