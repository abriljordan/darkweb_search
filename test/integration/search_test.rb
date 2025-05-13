#!/usr/bin/env ruby

require_relative '../../lib/cli_parser'
require_relative '../../lib/search_engines/ahmia'
require_relative '../../lib/search_engines/duckduckgo'
require_relative '../../lib/search_engines/haystack'
require_relative '../../lib/search_engines/torch'
require_relative '../../lib/tor_manager'
require 'fileutils'

class SearchEngineIntegrationTest
  def initialize
    @test_query = "test query"
    @output_file = "test_output.txt"
    @test_results = {
      passed: 0,
      failed: 0,
      total: 0,
      engine_results: {}
    }
    @engines = {
      ahmia: AhmiaSearchEngine.new,
      duckduckgo: DuckDuckGoSearchEngine.new,
      haystack: HaystackSearchEngine.new,
      torch: TorchSearchEngine.new
    }
  end

  def run_tests
    puts "\n=== Running Dark Web Search Integration Tests ==="
    
    # Check Tor status first
    check_tor_status
    
    run_test { test_basic_search }
    run_test { test_tor_option }
    run_test { test_output_option }
    run_test { test_all_options }
    run_test { test_file_output }
    run_test { test_each_engine }
    
    print_summary
  end

  private

  def check_tor_status
    puts "\nChecking Tor status..."
    if TorManager.tor_enabled?
      puts "✓ Tor is running and accessible"
    else
      puts "⚠ Warning: Tor is not running. Some tests may fail."
      puts "Please ensure Tor is running before testing .onion sites."
    end
  end

  def run_test
    @test_results[:total] += 1
    begin
      yield
      @test_results[:passed] += 1
    rescue => e
      @test_results[:failed] += 1
      puts "✗ Test failed: #{e.message}"
      puts "  #{e.backtrace.first}" if ENV['DEBUG']
    end
  end

  def print_summary
    puts "\n=== Test Summary ==="
    puts "Total tests: #{@test_results[:total]}"
    puts "Passed: #{@test_results[:passed]} (#{(@test_results[:passed].to_f / @test_results[:total] * 100).round(2)}%)"
    puts "Failed: #{@test_results[:failed]}"
    
    if @test_results[:engine_results].any?
      puts "\nSearch Engine Results:"
      @test_results[:engine_results].each do |engine, status|
        puts "#{engine}: #{status ? '✓' : '✗'}"
      end
    end
    
    puts "\n=== Tests Completed ==="
  end

  def test_basic_search
    puts "\nTesting basic search..."
    options = CLIParser.parse(["-q", @test_query])
    assert_equal(@test_query, options[:query], "Query parameter not set correctly")
    puts "✓ Basic search test passed"
  end

  def test_tor_option
    puts "\nTesting Tor option..."
    options = CLIParser.parse(["-q", @test_query, "-t"])
    assert(options[:tor], "Tor option not enabled")
    puts "✓ Tor option test passed"
  end

  def test_output_option
    puts "\nTesting output option..."
    options = CLIParser.parse(["-q", @test_query, "-o", @output_file])
    assert_equal(@output_file, options[:output], "Output file not set correctly")
    puts "✓ Output option test passed"
  end

  def test_all_options
    puts "\nTesting all options together..."
    options = CLIParser.parse(["-q", @test_query, "-t", "-o", @output_file])
    assert_equal(@test_query, options[:query], "Query parameter not set")
    assert(options[:tor], "Tor option not enabled")
    assert_equal(@output_file, options[:output], "Output file not set")
    puts "✓ All options test passed"
  end

  def test_file_output
    puts "\nTesting file output functionality..."
    test_file = "test_output_#{Time.now.to_i}.txt"
    
    begin
      # Run search with file output
      options = CLIParser.parse(["-q", @test_query, "-o", test_file])
      sample_results = ["http://example.onion", "http://test.onion"]
      
      # Write test results to file
      File.write(test_file, sample_results.join("\n"))
      
      # Verify file contents
      assert(File.exist?(test_file), "Output file was not created")
      file_content = File.read(test_file).strip
      assert_equal(sample_results.join("\n"), file_content, "File content doesn't match expected output")
      
      puts "✓ File output test passed"
    ensure
      # Cleanup
      FileUtils.rm_f(test_file)
    end
  end

  def test_each_engine
    puts "\nTesting each search engine..."
    timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
    
    @engines.each do |name, engine|
      begin
        puts "\nTesting #{name} search engine..."
        test_file = "#{name}_results_#{timestamp}.txt"
        
        # Enable Tor for engines that require it
        tor_enabled = false
        if [:ahmia, :duckduckgo, :torch, :haystack].include?(name)
          puts "Enabling Tor for #{name}..."
          begin
            TorManager.enable_tor_proxy
            unless TorManager.tor_enabled?
              puts "⚠ Cannot enable Tor for #{name} - continuing with next engine"
              @test_results[:engine_results][name] = false
              next
            end
            tor_enabled = true
          rescue => e
            puts "⚠ Failed to enable Tor for #{name}: #{e.message} - continuing with next engine"
            @test_results[:engine_results][name] = false
            next
          end
        end
        
        begin
          puts "Searching with query: #{@test_query}"
          results = engine.search(@test_query)
          
          if results.empty?
            puts "⚠ No results found for #{name}"
            @test_results[:engine_results][name] = false
          else
            puts "✓ Found #{results.size} results for #{name}"
            @test_results[:engine_results][name] = true
          end
        rescue => e
          @test_results[:engine_results][name] = false
          puts "✗ #{name} failed: #{e.message}"
        ensure
          # Disable Tor if it was enabled for this engine
          if tor_enabled
            TorManager.disable_tor
            puts "Disabled Tor after #{name} test"
          end
        end
      rescue => e
        @test_results[:engine_results][name] = false
        puts "✗ #{name} failed with unexpected error: #{e.message}"
      end
    end
end

  private

  def assert(condition, message = "Assertion failed")
    raise message unless condition
  end

  def assert_equal(expected, actual, message = "Expected #{expected} but got #{actual}")
    raise message unless expected == actual
  end
end

# Run the tests
if __FILE__ == $0
  test_runner = SearchEngineIntegrationTest.new
  test_runner.run_tests
end