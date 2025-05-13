require 'minitest/autorun'
require_relative '../../lib/tor_manager'

class TorManagerTest < Minitest::Test
  # Test that tor_enabled? returns true when Tor is running
  def test_tor_enabled_when_tor_is_running
    # Create a mock socket that responds to close
    mock_socket = Minitest::Mock.new
    mock_socket.expect :close, nil

    # Stub TCPSocket.new to return our mock socket
    TCPSocket.stub :new, mock_socket do
      assert TorManager.tor_enabled?
    end
  end

  # Test that tor_enabled? returns false when Tor is not running
  def test_tor_disabled_when_tor_is_not_running
    TCPSocket.stub :new, ->(*args) { raise Errno::ECONNREFUSED } do
      refute TorManager.tor_enabled?
    end
  end

  # Test successful Tor proxy enabling
  def test_enable_tor_proxy_success
    # Create a mock socket that responds to close
    mock_socket = Minitest::Mock.new
    mock_socket.expect :close, nil

    TCPSocket.stub :new, mock_socket do
      assert_nil TorManager.enable_tor_proxy
    end
  end

  # Test Tor proxy enabling failure
  def test_enable_tor_proxy_failure
    TCPSocket.stub :new, ->(*args) { raise Errno::ECONNREFUSED } do
      assert_raises(SystemExit) { TorManager.enable_tor_proxy }
    end
  end
end