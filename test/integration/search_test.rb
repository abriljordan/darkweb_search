#!/usr/bin/env ruby

require 'minitest/autorun'
require 'fileutils'
require_relative '../../darkweb_search'
require_relative '../../lib/search_engines/ahmia'
require_relative '../../lib/search_engines/torch'

class SearchEngineIntegrationTest < Minitest::Test
  def setup
    @search = DarkWebSearch::DarkWebSearch.new
    @test_queries = [
      "test AND query",
      "bitcoin AND wallet",
      "password manager"
    ]
    @results_dir = File.join(File.dirname(__FILE__), '../../results')
    FileUtils.mkdir_p(@results_dir)
    
    # Clean up any previous test files
    cleanup_test_files
  end

  def teardown
    cleanup_test_files
  end

  def test_command_line_search
    @test_queries.each do |query|
      output_file = "test_results_#{Time.now.to_i}.txt"
      
      # Test basic search
      results = @search.run(query, output: output_file)
      assert results, "Search should return results"
      
      # Verify results file was created
      result_path = File.join(@results_dir, output_file)
      assert File.exist?(result_path), "Results file should be created"
      
      # Check file contents
      content = File.read(result_path)
      assert_match(/Query: #{query}/, content, "Results should contain query")
      assert_match(/Total Results: \d+/, content, "Results should show total count")
      assert_match(/Source: (Ahmia|Torch)/, content, "Results should show source")
    end
  end

  def test_interactive_menu
    # Test menu initialization
    assert_respond_to @search, :run_interactive, "Should have interactive mode"
    
    # Simulate menu interactions
    test_menu_actions = {
      "1" => :perform_interactive_search,
      "2" => :show_recent_searches,
      "3" => :show_search_tips,
      "4" => :check_tor_connection,
      "5" => :show_settings
    }
    
    test_menu_actions.each do |input, method|
      assert_respond_to @search, method, "Should respond to #{method}"
    end
  end

  def test_search_engines
    # Test Ahmia search
    ahmia = DarkWebSearch::SearchEngines::AhmiaSearchEngine.new
    results = ahmia.search(@test_queries.first)
    assert_kind_of Set, results, "Ahmia should return a Set of results"
    
    # Test Torch search
    torch = DarkWebSearch::SearchEngines::TorchSearchEngine.new
    results = torch.search(@test_queries.first)
    assert_kind_of Set, results, "Torch should return a Set of results"
  end

  def test_tor_connection
    assert @search.test_tor_connection, "Tor connection should be available"
  end

  def test_result_formatting
    query = @test_queries.first
    output_file = "test_format_#{Time.now.to_i}.txt"
    
    @search.run(query, output: output_file)
    result_path = File.join(@results_dir, output_file)
    
    content = File.read(result_path)
    
    # Check formatting
    assert_match(/^Dark Web Search Results$/, content, "Should have title")
    assert_match(/^Query: /, content, "Should show query")
    assert_match(/^Timestamp: /, content, "Should have timestamp")
    assert_match(/^Total Results: \d+$/, content, "Should show result count")
    assert_match(/^\[[\d+]\] /, content, "Results should be numbered")
    assert_match(/^URL: http[s]?:\/\/.*\.onion/, content, "Should have .onion URLs")
  end

  def test_search_history
    # Perform searches
    @test_queries.each do |query|
      @search.run(query, output: "test_history_#{Time.now.to_i}.txt")
    end
    
    # Check history file
    history_file = File.join(@results_dir, 'search_history.txt')
    assert File.exist?(history_file), "Should create search history"
    
    content = File.read(history_file)
    @test_queries.each do |query|
      assert_match(/#{query}/, content, "History should contain query: #{query}")
    end
  end

  def test_error_handling
    # Test invalid query
    assert_nil @search.run("", output: "test_error.txt"), "Should handle empty query"
    
    # Test invalid output file
    assert_raises(Errno::EACCES) do
      @search.run(@test_queries.first, output: "/invalid/path/test.txt")
    end
  end

  private

  def cleanup_test_files
    Dir.glob(File.join(@results_dir, 'test_*')).each do |file|
      FileUtils.rm(file)
    end
  end
end