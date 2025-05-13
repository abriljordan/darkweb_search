require 'minitest/autorun'
require_relative '../../../lib/search_engines/duckduckgo'

class DuckDuckGoSearchEngineTest < Minitest::Test
  def setup
    @engine = DuckDuckGoSearchEngine.new
  end

  def test_search_with_valid_query
    mock_html = <<~HTML
      <html>
        <a class="result__url">http://test123.onion</a>
        <a class="result__url">http://example.onion</a>
      </html>
    HTML
    mock_response = Struct.new(:body).new(mock_html)
    
    @engine.stub :get_response, mock_response do
      results = @engine.search('test query')
      assert_equal 2, results.size
      assert results.all? { |url| url.include?('.onion') }
    end
  end

  def test_search_with_no_results
    mock_html = '<html><body>No results found</body></html>'
    mock_response = Struct.new(:body).new(mock_html)
    
    @engine.stub :get_response, mock_response do
      results = @engine.search('test query')
      assert_empty results
    end
  end

  def test_search_with_error
    @engine.stub :get_response, ->{ raise StandardError } do
      results = @engine.search('test query')
      assert_empty results
    end
  end
end