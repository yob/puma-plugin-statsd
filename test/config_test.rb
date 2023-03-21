require 'test_helper'

class ConfigTest < MiniTest::Test
  def setup
    # Do nothing
  end

  def teardown
    PumaStatsd.reset_config
    %w[
        STATSD_HOST
        STATSD_PORT
        STATSD_SOCKET_PATH
        MY_POD_NAME
        STATSD_GROUPING
        STATSD_METRIC_PREFIX
        STATSD_SLEEP_INTERVAL
        DD_TAGS
        DD_ENV
        DD_SERVICE
        DD_VERSION
        DD_ENTITY_ID
    ].each {|var| ENV.delete var }
  end

  def test_config
    assert_kind_of OpenStruct, PumaStatsd.config
  end

  def test_config_defaults
    assert_nil PumaStatsd.config.pod_name
    assert_nil PumaStatsd.config.statsd_grouping

    assert_equal '127.0.0.1', PumaStatsd.config.statsd_host
    assert_equal 8125       , PumaStatsd.config.statsd_port
  end

  def test_config_from_default_env
    ENV['STATSD_HOST']           = 'test.com'
    ENV['STATSD_PORT']           = '1234'
    ENV['MY_POD_NAME']           = 'sample_pod'
    ENV['STATSD_SOCKET_PATH']    = '/var/lib/statsd/statsd.sock'
    ENV['STATSD_GROUPING']       = 'sample_group'
    ENV['STATSD_METRIC_PREFIX']  = 'sample'
    ENV['STATSD_SLEEP_INTERVAL'] = '0.5'
    ENV['DD_TAGS']               = 'aaa,bbb'
    ENV['DD_ENV']                = 'staging'
    ENV['DD_SERVICE']            = 'sample_service'
    ENV['DD_VERSION']            = '2.0.0'
    ENV['DD_ENTITY_ID']          = 'sample_entity_id'

    assert_equal 'test.com'                   , PumaStatsd.config.statsd_host
    assert_equal '1234'                       , PumaStatsd.config.statsd_port
    assert_equal 'sample_pod'                 , PumaStatsd.config.pod_name
    assert_equal '/var/lib/statsd/statsd.sock', PumaStatsd.config.statsd_socket_path
    assert_equal 'sample_group'               , PumaStatsd.config.statsd_grouping
    assert_equal '0.5'                        , PumaStatsd.config.statsd_sleep_interval
    assert_equal 'sample'                     , PumaStatsd.config.metric_prefix
    assert_equal 'aaa,bbb'                    , PumaStatsd.config.dd_tags
    assert_equal 'staging'                    , PumaStatsd.config.dd_env
    assert_equal 'sample_service'             , PumaStatsd.config.dd_service
    assert_equal '2.0.0'                      , PumaStatsd.config.dd_version
    assert_equal 'sample_entity_id'           , PumaStatsd.config.dd_entity_id
  end

  def test_configure_block
    PumaStatsd.configure do |config|
      config.statsd_host           = 'test.com'
      config.statsd_port           = '1234'
      config.pod_name              = 'sample_pod'
      config.statsd_socket_path    = '/var/lib/statsd/statsd.sock'
      config.statsd_grouping       = 'sample_group'
      config.statsd_sleep_interval = '0.5'
      config.metric_prefix         = 'sample'
      config.dd_tags               = 'aaa,bbb'
      config.dd_env                = 'staging'
      config.dd_service            = 'sample_service'
      config.dd_version            = '2.0.0'
      config.dd_entity_id          = 'sample_entity_id'
    end

    assert_equal 'test.com'                   , PumaStatsd.config.statsd_host
    assert_equal '1234'                       , PumaStatsd.config.statsd_port
    assert_equal 'sample_pod'                 , PumaStatsd.config.pod_name
    assert_equal '/var/lib/statsd/statsd.sock', PumaStatsd.config.statsd_socket_path
    assert_equal 'sample_group'               , PumaStatsd.config.statsd_grouping
    assert_equal '0.5'                        , PumaStatsd.config.statsd_sleep_interval
    assert_equal 'sample'                     , PumaStatsd.config.metric_prefix
    assert_equal 'aaa,bbb'                    , PumaStatsd.config.dd_tags
    assert_equal 'staging'                    , PumaStatsd.config.dd_env
    assert_equal 'sample_service'             , PumaStatsd.config.dd_service
    assert_equal '2.0.0'                      , PumaStatsd.config.dd_version
    assert_equal 'sample_entity_id'           , PumaStatsd.config.dd_entity_id
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
