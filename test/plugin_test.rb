require "test_helper"

class PluginTest < Minitest::Test
  def test_registration
    assert_kind_of Class, Puma::Plugins.find("statsd")
  end

  def test_tags_empty_default
    assert_nil plugin.send(:environment_variable_tags)
  end

  def test_tags_from_env
    ENV['MY_POD_NAME'] = 'sample_pod'
    ENV['STATSD_GROUPING'] = 'sample_grouping'
    tags = plugin.send(:environment_variable_tags)

    assert_includes tags, 'pod_name:sample_pod'
    assert_includes tags, 'grouping:sample_grouping'
  end

  def test_tags_from_config
    PumaStatsd.config.pod_name = 'sample_pod'
    PumaStatsd.config.statsd_grouping = 'sample_grouping'
    tags = plugin.send(:environment_variable_tags)

    assert_includes tags, 'pod_name:sample_pod'
    assert_includes tags, 'grouping:sample_grouping'
  end

  def teardown
    PumaStatsd.reset_config
    %w[STATSD_HOST STATSD_PORT MY_POD_NAME STATSD_GROUPING].each {|var| ENV.delete var }
  end

  def plugin
    Puma::PluginLoader.new.create("statsd")
  end
end
