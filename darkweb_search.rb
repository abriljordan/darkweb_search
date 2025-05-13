#!/usr/bin/env ruby

require_relative 'lib/config'
require_relative 'lib/cli_parser'
require_relative 'lib/tor_manager'
require_relative 'lib/search_engines/factory'
require 'concurrent'

module DarkWebSearch
  class Application
    def initialize
      Config.load
      @logger = Config.logger
      @options = {}
      if ARGV.empty?
        show_main_menu
      else
        @options = CLIParser.parse(ARGV)
      end
      exit if @options.empty?
    end

    def show_main_menu
      loop do
        clear_screen
        show_banner
        show_current_config
        show_menu_options
        
        choice = get_user_input("\nSelect an option (0-7): ")
        
        case choice
        when "1"
          set_search_query
        when "2"
          select_search_engines
        when "3"
          toggle_tor
        when "4"
          set_output_file
        when "5"
          show_help
        when "6"
          if validate_config
            break # Exit menu and start search
          end
        when "7"
          show_about
        when "0"
          puts "\nExiting..."
          exit
        else
          puts "\nInvalid option. Press Enter to continue..."
          gets
        end
      end
    end

    def run
      setup_environment
      results = perform_search
      display_results(results)
      save_results(results) if @options[:output]
    rescue => e
      @logger.error("Application error: #{e.message}")
      puts "[!] Error: #{e.message}"
      exit 1
    ensure
      cleanup
    end

    private

    def clear_screen
      system('clear') || system('cls')
    end

    def show_banner
      puts CLIParser.show_banner
      puts "\n=== Dark Web Search Tool ==="
      puts "A terminal-based dark web search utility"
      puts "=" * 35 + "\n\n"
    end

    def show_current_config
      puts "Current Configuration:"
      puts "---------------------"
      puts "Search Query: #{@options[:query] || 'Not set'}"
      puts "Search Engines: #{@options[:engines]&.join(', ') || 'Not set'}"
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
      query = get_user_input("\nEnter search query: ")
      @options[:query] = query unless query.empty?
    end

    def select_search_engines
      clear_screen
      puts "\nAvailable Search Engines:"
      puts "----------------------"
      
      CLIParser::AVAILABLE_ENGINES.each_with_index do |(key, desc), index|
        puts "#{index + 1}. #{key.ljust(12)} - #{desc}"
      end

      puts "\nEnter engine numbers (comma-separated) or 'all'"
      print "Selection: "
      input = gets.chomp.downcase

      if input == 'all'
        @options[:engines] = CLIParser::AVAILABLE_ENGINES.keys
      else
        selected = input.split(',').map(&:strip).map(&:to_i)
        @options[:engines] = selected.map { |i| CLIParser::AVAILABLE_ENGINES.keys[i - 1] }.compact
      end
    end

    def toggle_tor
      @options[:tor] = !@options[:tor]
      puts "\nTor #{@options[:tor] ? 'enabled' : 'disabled'}. Press Enter to continue..."
      gets
    end

    def set_output_file
      filename = get_user_input("\nEnter output filename (or Enter to skip): ")
      if filename.empty?
        @options.delete(:output)
      else
        @options[:output] = filename
      end
    end

    def show_help
      clear_screen
      puts CLIParser.show_help
      puts "\nPress Enter to continue..."
      gets
    end

    def show_about
      clear_screen
      puts "\nDark Web Search Tool v1.0"
      puts "-------------------------"
      puts "A terminal-based utility for searching the dark web"
      puts "Supports multiple search engines and Tor routing"
      puts "\nSupported Search Engines:"
      CLIParser::AVAILABLE_ENGINES.each do |key, desc|
        puts "- #{key}: #{desc}"
      end
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

      if @options[:engines].nil? || @options[:engines].empty?
        @options[:engines] = ['ahmia'] # Set default engine
      end

      true
    end

    def get_user_input(prompt)
      print prompt
      gets.chomp
    end

    def setup_environment
      if @options[:tor]
        @logger.info("Enabling Tor proxy")
        unless TorManager.enable_tor_proxy
          @logger.error("Failed to enable Tor proxy")
          exit 1
        end
      end

      FileUtils.mkdir_p(Config.settings[:results_dir])
    end

    def perform_search
      engines = SearchEngines::Factory.create_engines(@options[:engines])
      @logger.info("Starting search with query: #{@options[:query]}")
      
      if Config.settings[:search][:concurrent]
        search_concurrent(engines)
      else
        search_sequential(engines)
      end
    end

    def search_concurrent(engines)
      futures = engines.map do |engine|
        Concurrent::Future.execute do
          begin
            engine.search(@options[:query])
          rescue => e
            @logger.error("Search failed for #{engine.class}: #{e.message}")
            Set.new
          end
        end
      end

      # Wait for all searches to complete and combine results
      futures.map(&:value).reduce(Set.new, :merge)
    end

    def search_sequential(engines)
      engines.reduce(Set.new) do |results, engine|
        begin
          results.merge(engine.search(@options[:query]))
        rescue => e
          @logger.error("Search failed for #{engine.class}: #{e.message}")
          results
        end
      end
    end

    def display_results(results)
      if results.empty?
        puts "[-] No results found."
      else
        puts "[✓] Found #{results.size} unique result(s)."
        results.each_with_index do |result, i|
          puts "\n#{i + 1}. #{result.title || result.url}"
          puts "   URL: #{result.url}"
          puts "   Engine: #{result.engine}"
          puts "   Description: #{result.description}" if result.description
        end
      end
    end

    def save_results(results)
      output_file = File.join(Config.settings[:results_dir], @options[:output])
      
      File.open(output_file, 'w') do |f|
        f.puts "Dark Web Search Results"
        f.puts "Query: #{@options[:query]}"
        f.puts "Timestamp: #{Time.now}"
        f.puts "Total Results: #{results.size}"
        f.puts "-" * 50
        f.puts

        results.each_with_index do |result, i|
          f.puts "#{i + 1}. #{result.title || result.url}"
          f.puts "URL: #{result.url}"
          f.puts "Engine: #{result.engine}"
          f.puts "Description: #{result.description}" if result.description
          f.puts "-" * 30
          f.puts
        end
      end

      puts "[✓] Results saved to #{output_file}"
    end

    def cleanup
      TorManager.disable_tor if @options[:tor]
    end
  end
end

if __FILE__ == $0
  DarkWebSearch::Application.new.run
end
