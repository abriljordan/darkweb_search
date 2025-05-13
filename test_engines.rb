#!/usr/bin/env ruby

require_relative 'lib/config'
require_relative 'lib/tor_manager'
require_relative 'lib/search_engines/factory'

def test_engine(engine, query)
  puts "\nTesting #{engine.class.name}"
  puts "=" * 50
  
  begin
    results = engine.search(query)
    puts "[✓] Search completed"
    puts "[✓] Found #{results.size} results"
    
    # Show first result as sample
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
query = "test"
puts "\nUsing test query: '#{query}'"

# Create and test each engine
engines = %w[ahmia torch haystack duckduckgo]
engines.each do |engine_name|
  engine = DarkWebSearch::SearchEngines::Factory.create_engines([engine_name]).first
  test_engine(engine, query)
end

puts "\nTest completed!"
