#!/usr/bin/env ruby

require_relative 'lib/config'
require_relative 'lib/tor_manager'
require_relative 'lib/search_engines/factory'
require_relative 'lib/cli_parser'
require 'open3'

def test_cli_mode
  puts "\n=== Testing CLI Mode ==="
  puts "=" * 50

  test_cases = [
    {
      desc: "Single engine search (Ahmia)",
      cmd: "./darkweb_search.rb -q 'password AND gmail' -e ahmia"
    },
    {
      desc: "Multiple engines search",
      cmd: "./darkweb_search.rb -q 'password AND gmail' -e ahmia,torch"
    },
    {
      desc: "Search with Tor enabled",
      cmd: "./darkweb_search.rb -q 'password AND gmail' -e ahmia -t"
    },
    {
      desc: "Search with output file",
      cmd: "./darkweb_search.rb -q 'password AND gmail' -e ahmia -o test_results.txt"
    }
  ]

  test_cases.each do |test|
    puts "\nTesting: #{test[:desc]}"
    puts "Command: #{test[:cmd]}"
    puts "-" * 30
    
    stdout, stderr, status = Open3.capture3(test[:cmd])
    
    if status.success?
      puts "[✓] Test passed"
      puts "Output preview:"
      puts stdout.split("\n").take(5)
    else
      puts "[✗] Test failed"
      puts "Error: #{stderr}"
    end
  end
end

def test_engine_directly(engine, query)
  puts "\nTesting #{engine.class.name}"
  puts "=" * 30
  
  begin
    results = engine.search(query)
    puts "[✓] Search completed"
    puts "[✓] Found #{results.size} results"
    
    if results.any?
      puts "\nSample result:"
      puts "Title: #{results.first.title}"
      puts "URL: #{results.first.url}"
    end
    
  rescue => e
    puts "[✗] Error: #{e.message}"
    puts e.backtrace.take(3)
  end
end

def test_individual_engines
  puts "\n=== Testing Individual Engines ==="
  puts "=" * 50

  # Initialize
  puts "Initializing..."
  DarkWebSearch::Config.load

  # Enable Tor
  puts "\nEnabling Tor..."
  unless DarkWebSearch::TorManager.enable_tor_proxy
    puts "[✗] Failed to enable Tor. Exiting."
    exit 1
  end

  # Test query
  query = "password AND gmail"
  puts "\nUsing test query: '#{query}'"

  # Test each engine individually
  %w[ahmia torch haystack duckduckgo].each do |engine_name|
    engine = DarkWebSearch::SearchEngines::Factory.create_engines([engine_name]).first
    test_engine_directly(engine, query) if engine
  end
end

def test_interactive_mode
  puts "\n=== Testing Interactive Mode ==="
  puts "=" * 50
  
  cmd = "echo '1\npassword AND gmail\n2\n1\n6\n0\n' | ./darkweb_search.rb"
  puts "Simulating interactive input sequence:"
  puts "1. Set search query to 'password AND gmail'"
  puts "2. Select search engine (Ahmia)"
  puts "6. Start search"
  puts "0. Exit"
  
  stdout, stderr, status = Open3.capture3(cmd)
  
  if status.success?
    puts "[✓] Interactive test passed"
    puts "Output preview:"
    puts stdout.split("\n").take(10)
  else
    puts "[✗] Interactive test failed"
    puts "Error: #{stderr}"
  end
end

# Run all tests
puts "Starting Dark Web Search Tool Tests"
puts "=================================="

begin
  test_cli_mode
  test_individual_engines
  test_interactive_mode
rescue => e
  puts "\n[✗] Test suite failed:"
  puts e.message
  puts e.backtrace.take(5)
ensure
  # Cleanup
  DarkWebSearch::TorManager.disable_tor
  puts "\nTest suite completed!"
end
