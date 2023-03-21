require "test_helper"

class StatsdConnectorTest < Minitest::Test
  def test_host
    ENV['STATSD_HOST'] = 'test.com'

    connector = StatsdConnector.new
    assert_equal 'test.com', connector.host
  end

  def test_port
    ENV['STATSD_PORT'] = '1234'
    connector = StatsdConnector.new
    assert_equal "1234", connector.port
  end

  def test_port_default
    connector = StatsdConnector.new
    assert_equal 8125, connector.port
  end

  def test_sends_to_configured_host_port
    ENV['STATSD_HOST'] = 'test.com'
    ENV['STATSD_PORT'] = '1234'
    connector = StatsdConnector.new

    mock_socket = Minitest::Mock.new
    mock_socket.expect :send, true, [String, Integer, 'test.com', '1234']
    def mock_socket.close; nil; end

    connector.stub :udp_socket, mock_socket do
      connector.send(metric_name: 'test',value: 1,type: :count)
    end

    assert mock_socket.verify
  end

  def test_sends_count_metric
    ENV['STATSD_HOST'] = 'test.com'
    ENV['STATSD_PORT'] = '1234'
    connector = StatsdConnector.new

    mock_socket = Minitest::Mock.new
    mock_socket.expect :send, true, ['test:1|c', Integer, String, String]
    def mock_socket.close; nil; end

    connector.stub :udp_socket, mock_socket do
      connector.send(metric_name: 'test',value: 1,type: :count)
    end

    assert mock_socket.verify
  end

  def test_sends_gauge_metric
    ENV['STATSD_HOST'] = 'test.com'
    ENV['STATSD_PORT'] = '1234'
    connector = StatsdConnector.new

    mock_socket = Minitest::Mock.new
    mock_socket.expect :send, true, ['test:1|g', Integer,String, String]
    def mock_socket.close; nil; end

    connector.stub :udp_socket, mock_socket do
      connector.send(metric_name: 'test',value: 1,type: :gauge)
    end

    assert mock_socket.verify
  end

  def teardown
    %w[STATSD_HOST STATSD_PORT].each {|var| ENV.delete var }
    PumaStatsd.reset_config
  end
end
