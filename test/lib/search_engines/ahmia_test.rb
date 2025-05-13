require 'minitest/autorun'
require_relative '../../../lib/search_engines/ahmia'

class AhmiaSearchEngineTest < Minitest::Test
  def setup
    @engine = AhmiaSearchEngine.new
  end

  def test_search_with_valid_query
    # Mock successful response with onion links
    mock_html = 'Some text http://abc123def456.onion/page Some more text'
    mock_response = Struct.new(:body).new(mock_html)
    
    @engine.stub :get_response, mock_response do
      results = @engine.search('test query')
      assert_equal ['http://abc123def456.onion/page'], results
    end
  end

  def test_search_with_no_results
    # Mock response with no onion links
    mock_response = Struct.new(:body).new('No onion links here')
    
    @engine.stub :get_response, mock_response do
      results = @engine.search('test query')
      assert_empty results
    end
  end

  def test_search_with_multiple_results
    # Mock response with multiple onion links
    mock_html = <<~HTML
      http://abc123.onion/page1
      http://def456.onion/page2
      http://ghi789.onion/page3
    HTML
    mock_response = Struct.new(:body).new(mock_html)
    
    @engine.stub :get_response, mock_response do
      results = @engine.search('test query')
      assert_equal 3, results.size
      assert results.all? { |url| url.include?('.onion') }
    end
  end
end