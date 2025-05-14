#!/usr/bin/env ruby

require_relative 'lib/config'
require_relative 'lib/search_engines/ahmia'
require_relative 'lib/search_engines/torch'
require 'logger'
require 'set'
require 'fileutils'
require 'optparse'

module DarkWebSearch
  class SearchResult
    attr_reader :url, :title, :description, :engine
    
    def initialize(url:, title:, description: nil, engine:)
      @url = url
      @title = title
      @description = description
      @engine = engine
    end
  end

  class DarkWebSearch
    def initialize
      Config.load # Initialize config with defaults
      @logger = Config.logger
      @options = {
        query: nil,
        output: nil,
        tor: true
      }
      
      # Initialize only working search engines
      @search_engines = [
        SearchEngines::AhmiaSearchEngine.new,
        SearchEngines::TorchSearchEngine.new
      ]
      
      @logger.info("Dark Web Search initialized with #{@search_engines.size} engines")
    end

    def run_interactive
      loop do
        clear_screen
        show_banner
        show_current_config
        show_menu_options
        
        print "\nSelect an option (0-7): "
        choice = gets.chomp
        
        case choice
        when '0'
          puts "\nExiting..."
          break
        when '1'
          set_search_query
        when '2'
          select_search_engines
        when '3'
          toggle_tor
        when '4'
          set_output_file
        when '5'
          show_help
        when '6'
          if validate_config
            results = perform_search
            display_results(results)
            save_results(results) if @options[:output]
            puts "\nPress Enter to continue..."
            gets
          end
        when '7'
          show_about
        else
          puts "\nInvalid option. Press Enter to continue..."
          gets
        end
      end
    end

    def run(query, options)
      return false if query.nil? || query.empty?
      
      @options[:query] = query
      if test_tor_connection
        results = perform_search
        display_results(results)
        save_results(results, options[:output]) if options[:output]
        true
      else
        puts "[!] Error: Could not connect to Tor. Please ensure Tor is running."
        false
      end
    end

    private

    def clear_screen
      system('clear') || system('cls')
    end

    def show_banner
      puts "Dark Web Search Tool"
      puts "---------------------"
      puts "A terminal-based dark web search utility"
      puts "=" * 35 + "\n\n"
    end

    def show_current_config
      puts "Current Configuration:"
      puts "---------------------"
      puts "Search Query: #{@options[:query] || 'Not set'}"
      puts "Use Tor: #{@options[:tor] ? 'Yes' : 'No'}"
      puts "Output File: #{@options[:output] || 'Not set'}"
      puts "\n"
    end

    def show_menu_options
      puts "Menu Options:"
      puts "------------"
      puts "1. Set Search Query"
      puts "2. Select Search Engines"
      puts "3. Toggle Tor Usage"
      puts "4. Set Output File"
      puts "5. Show Help"
      puts "6. Start Search"
      puts "7. About"
      puts "0. Exit"
    end

    def set_search_query
      print "\nEnter search query: "
      query = gets.chomp
      @options[:query] = query unless query.empty?
    end

    def select_search_engines
      clear_screen
      puts "\nAvailable Search Engines:"
      puts "----------------------"
      @search_engines.each_with_index do |engine, index|
        puts "#{index + 1}. #{engine.class.name.split('::').last}"
      end
      puts "\nNote: Currently using all available engines"
      puts "Press Enter to continue..."
      gets
    end

    def toggle_tor
      @options[:tor] = !@options[:tor]
      puts "\nTor #{@options[:tor] ? 'enabled' : 'disabled'}. Press Enter to continue..."
      gets
    end

    def set_output_file
      print "\nEnter output filename (or Enter to skip): "
      filename = gets.chomp
      if filename.empty?
        @options.delete(:output)
      else
        @options[:output] = filename
      end
    end

    def show_help
      clear_screen
      puts "Dark Web Search Tool Help"
      puts "-------------------------"
      puts "A terminal-based utility for searching the dark web"
      puts "Supports multiple search engines and Tor routing"
      puts "\nSupported Search Engines:"
      @search_engines.each do |engine|
        puts "- #{engine.class.name.split('::').last}"
      end
      puts "\nPress Enter to continue..."
      gets
    end

    def show_about
      clear_screen
      puts "\nDark Web Search Tool v1.0"
      puts "-------------------------"
      puts "A terminal-based utility for searching the dark web"
      puts "Supports multiple search engines and Tor routing"
      puts "\nPress Enter to continue..."
      gets
    end

    def validate_config
      if @options[:query].nil? || @options[:query].empty?
        puts "\nError: Search query is required!"
        puts "Press Enter to continue..."
        gets
        return false
      end
      true
    end

    def perform_search
      @logger.info("Starting search with query: #{@options[:query]}")
      
      # Run searches in parallel for better performance
      threads = @search_engines.map do |engine|
        Thread.new do
          begin
            engine.search(@options[:query])
          rescue => e
            @logger.error("Search failed for #{engine.class}: #{e.message}")
            Set.new
          end
        end
      end

      # Combine results from all engines, removing duplicates
      results = threads.map(&:value).reduce(Set.new, :merge)
      
      @logger.info("Search completed. Found #{results.size} total unique results")
      results.to_a
    end

    def display_results(results)
      if results.empty?
        puts "\nNo results found."
      else
        puts "\nFound #{results.size} unique results:"
        puts "=" * 80
        
        results.each_with_index do |result, i|
          puts "\n[#{i + 1}] #{clean_text(result.title)}"
          puts "    URL: #{result.url}"
          if result.description
            # Word wrap description at 76 chars for readability
            description = clean_text(result.description)
            description = description.gsub(/(.{1,76})(\s+|$)/, "    \\1\n").strip
            puts "    Description:\n#{description}"
          end
          puts "    Source: #{result.engine.capitalize}"
          puts "-" * 80
        end
      end
    end

    def save_results(results, output_file)
      FileUtils.mkdir_p('results')
      output_file ||= "results_#{Time.now.strftime('%Y%m%d_%H%M%S')}.txt"
      output_file = File.join('results', output_file)
      
      File.open(output_file, 'w:UTF-8') do |f|
        f.puts "Dark Web Search Results"
        f.puts "Query: #{@options[:query]}"
        f.puts "Timestamp: #{Time.now}"
        f.puts "Total Results: #{results.size}"
        f.puts "=" * 80
        f.puts

        results.each_with_index do |result, i|
          f.puts "[#{i + 1}] #{clean_text(result.title)}"
          f.puts "URL: #{result.url}"
          if result.description
            f.puts "Description:"
            # Word wrap description at 76 chars for readability
            description = clean_text(result.description)
            description = description.gsub(/(.{1,76})(\s+|$)/, "\\1\n").strip
            f.puts description
          end
          f.puts "Source: #{result.engine.capitalize}"
          f.puts "-" * 80
          f.puts
        end
      end

      puts "\n[✓] Results saved to: #{output_file}"
    end

    def test_tor_connection
      @logger.info("Testing Tor connection...")
      begin
        require 'socket'
        TCPSocket.new('127.0.0.1', 9050).close
        @logger.info("Tor connection successful")
        true
      rescue => e
        @logger.error("Tor connection failed: #{e.message}")
        false
      end
    end

    private

    def clean_text(text)
      return "" unless text
      
      # Convert to UTF-8 if not already
      text = text.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
      
      # Replace common HTML entities
      text = text.gsub(/&amp;/, '&')
                .gsub(/&lt;/, '<')
                .gsub(/&gt;/, '>')
                .gsub(/&quot;/, '"')
                .gsub(/&#39;/, "'")
                .gsub(/&ndash;/, '–')
                .gsub(/&mdash;/, '—')
                .gsub(/&nbsp;/, ' ')
      
      # Replace or remove problematic characters
      text = text.gsub(/[\u0080-\u009F]/, '') # Remove control characters
                .gsub(/[^\p{Print}\s]/, '')    # Remove non-printable characters
                .gsub(/\s+/, ' ')              # Normalize whitespace
                .strip
      
      # Handle common encoding issues
      text = text.gsub(/â\u0080\u0099/, "'")  # Smart quotes
                .gsub(/â\u0080\u009C/, '"')    # Left double quote
                .gsub(/â\u0080\u009D/, '"')    # Right double quote
                .gsub(/â\u0080\u0093/, '–')    # En dash
                .gsub(/â\u0080\u0094/, '—')    # Em dash
                .gsub(/â\u0080¦/, '...')       # Ellipsis
                .gsub(/Â/, '')                 # Non-breaking space artifact
      
      text
    end
  end
end

# Only run this code if the script is run directly
if $0 == __FILE__
  search = DarkWebSearch::DarkWebSearch.new
  
  if ARGV.empty? || ARGV[0] == '-h' || ARGV[0] == '--help'
    puts <<~HELP
      Dark Web Search Tool - Search the dark web safely through Tor

      Usage:
        #{File.basename($0)} [options] <search query>
        #{File.basename($0)} -i  # Interactive mode

      Options:
        -h, --help     Show this help message
        -i            Interactive mode (menu-driven interface)
        -o FILE       Save results to FILE (default: results_TIMESTAMP.txt)
        -v            Verbose output (shows debug information)
        -q            Quiet mode (only shows results)

      Examples:
        #{File.basename($0)} "bitcoin wallet"
        #{File.basename($0)} -o results.txt "password manager"
        #{File.basename($0)} -i  # Start in interactive mode

      Notes:
        - Requires Tor to be running (default: localhost:9050)
        - Searches multiple dark web search engines
        - Results are automatically saved to the results/ directory
        - Use quotes for queries with spaces
        - Use AND, OR, NOT for boolean queries (e.g., "bitcoin AND wallet")

      Safety Warning:
        This tool helps you search the dark web safely, but exercise caution:
        - Never download files from .onion sites
        - Never enter credentials on .onion sites
        - Use Tor Browser for actually visiting any sites
    HELP
    exit 0
  end

  # Parse command line options
  require 'optparse'
  options = { verbose: false, quiet: false }
  
  parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename($0)} [options] <search query>"
    
    opts.on('-i', '--interactive', 'Interactive mode') do
      options[:interactive] = true
    end
    
    opts.on('-o', '--output FILE', 'Save results to FILE') do |file|
      options[:output] = file
    end
    
    opts.on('-v', '--verbose', 'Verbose output') do
      options[:verbose] = true
    end
    
    opts.on('-q', '--quiet', 'Quiet mode') do
      options[:quiet] = true
    end
  end

  begin
    parser.parse!
    
    if options[:interactive]
      search.run_interactive
    else
      if ARGV.empty?
        puts "Error: Please provide a search query or use -i for interactive mode"
        puts "Use --help for usage information"
        exit 1
      end
      
      query = ARGV.join(' ')
      search.run(query, options)
    end
  rescue OptionParser::InvalidOption => e
    puts "Error: #{e.message}"
    puts "Use --help for usage information"
    exit 1
  rescue Interrupt
    puts "\nSearch cancelled."
    exit 0
  rescue => e
    puts "Error: #{e.message}"
    puts e.backtrace if options[:verbose]
    exit 1
  end
end
