require 'minitest/autorun'
require_relative '../../../lib/search_engines/base_engine'

class BaseSearchEngineTest < Minitest::Test
  def setup
    @engine = BaseSearchEngine.new
  end

  def test_search_raises_not_implemented
    assert_raises(NotImplementedError) { @engine.search('test') }
  end

  def test_get_response_success
    # Create mock HTTP response that inherits from Net::HTTPSuccess
    mock_response = Class.new(Net::HTTPSuccess) do
      def initialize
        @code = '200'
        @body = 'test response'
      end
      attr_reader :code, :body
    end.new

    # Mock the HTTP request
    Net::HTTP.stub :get_response, mock_response do
      response = @engine.send(:get_response, 'http://test.com')
      assert_equal mock_response, response
    end
  end

  def test_get_response_network_failure
    Net::HTTP.stub :get_response, ->(*args) { raise SocketError, "Failed to connect" } do
      output = capture_io do
        assert_raises(SystemExit) { @engine.send(:get_response, 'http://test.com') }
      end
      assert_match(/Network connection failed/, output.join)
    end
  end

  def test_get_response_invalid_url
    output = capture_io do
      assert_raises(SystemExit) { @engine.send(:get_response, 'not_a_url') }
    end
    assert_match(/Invalid URL format/, output.join)
  end
end