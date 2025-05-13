require 'minitest/autorun'
require_relative '../../../lib/search_engines/torch'

class TorchSearchEngineTest < Minitest::Test
  def setup
    @engine = TorchSearchEngine.new
  end

  def test_search_without_tor
    TorManager.stub :tor_enabled?, false do
      results = @engine.search('test query')
      assert_empty results
    end
  end

  def test_search_with_tor_and_valid_results
    TorManager.stub :tor_enabled?, true do
      mock_html = <<~HTML
        <html>
          <a href="http://test123.onion">Link 1</a>
          <a href="http://example.onion">Link 2</a>
        </html>
      HTML
      mock_response = Struct.new(:body).new(mock_html)
      
      @engine.stub :get_response, mock_response do
        results = @engine.search('test query')
        assert_equal 2, results.size
        assert results.all? { |url| url.include?('.onion') }
      end
    end
  end

  def test_search_with_error
    TorManager.stub :tor_enabled?, true do
      @engine.stub :get_response, ->{ raise StandardError } do
        results = @engine.search('test query')
        assert_empty results
      end
    end
  end

  def test_search_with_mixed_results
    TorManager.stub :tor_enabled?, true do
      mock_html = <<~HTML
        <html>
          <a href="http://test123.onion">Onion Link</a>
          <a href="http://regular-site.com">Regular Link</a>
        </html>
      HTML
      mock_response = Struct.new(:body).new(mock_html)
      
      @engine.stub :get_response, mock_response do
        results = @engine.search('test query')
        assert_equal 1, results.size
        assert results.first.include?('.onion')
      end
    end
  end
end