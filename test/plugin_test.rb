require "test_helper"

class PluginTest < Minitest::Test
  def test_registration
    assert_kind_of Class, Puma::Plugins.find("statsd")
  end

  def test_tags_empty_default
    assert_empty plugin.send(:tags)
  end

  def test_tags_from_env
    ENV['MY_POD_NAME'] = 'sample_pod'
    ENV['STATSD_GROUPING'] = 'sample_grouping'
    tags = plugin.send(:tags)

    assert_equal 'sample_pod', tags[:pod_name]
    assert_equal 'sample_grouping', tags[:grouping]
  end

  def teardown
    %w[STATSD_HOST STATSD_PORT MY_POD_NAME STATSD_GROUPING].each {|var| ENV.delete var }
  end

  def plugin
    Puma::PluginLoader.new.create("statsd")
  end
end
