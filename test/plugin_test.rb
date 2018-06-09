require "test_helper"

class PluginTest < Minitest::Test
  def test_registration
    assert_kind_of Class, Puma::Plugins.find("systemd")
  end
end
