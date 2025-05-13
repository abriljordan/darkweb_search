require 'open-uri'
require 'nokogiri'
require_relative '../tor_manager'
require_relative 'base_engine'
require 'ferrum'

module DarkWebSearch
  module SearchEngines
    class DuckDuckGoSearchEngine < BaseSearchEngine
      DUCKDUCKGO_URL = "https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion"

      def initialize
        super
        @base_url = DUCKDUCKGO_URL
      end

      def search(query)
        @logger.info("Starting DuckDuckGo search for query: #{query}")
        browser = setup_browser
        
        begin
          results = fetch_results(browser, query)
          @logger.info("Found #{results.size} results from DuckDuckGo")
          results
        rescue SearchError => e
          @logger.error("DuckDuckGo search failed: #{e.message}")
          []
        ensure
          cleanup_browser(browser)
        end
      end

      private

      def setup_browser
        Ferrum::Browser.new(
          browser_options: {
            'no-sandbox': nil,
            'proxy-server': "socks5://127.0.0.1:9050"
          },
          timeout: 120,
          window_size: [1366, 768]
        )
      rescue => e
        @logger.error("Failed to initialize browser: #{e.message}")
        raise SearchError, "Browser initialization failed: #{e.message}"
      end

      def fetch_results(browser, query)
        formatted_query = URI.encode_www_form_component("#{query} site:.onion")
        url = "#{@base_url}/?q=#{formatted_query}&ia=web"
        @logger.debug("Navigating to: #{url}")
        
        browser.go_to(url)
        browser.network.wait_for_idle(timeout: 30)
        sleep 8  # Give more time for JavaScript execution

        parse_results(browser.body)
      rescue => e
        @logger.error("Failed to fetch results: #{e.message}")
        raise SearchError, "Failed to fetch results: #{e.message}"
      end

      def parse_results(html)
        doc = Nokogiri::HTML(html)
        results = Set.new

        # Parse main search results
        doc.css('.result').each do |result|
          link = result.at_css('.result__title a')
          next unless link
          
          url = link['href']
          next unless url && url.match?(/\.onion/)

          title = link.text.strip
          description = result.at_css('.result__snippet')&.text&.strip || ''

          results << SearchResult.new(
            url: url,
            title: title,
            description: description,
            engine: 'duckduckgo'
          )
        end

        # Also check for deep results
        doc.css('.results_links_deep').each do |result|
          link = result.at_css('a.result__url')
          next unless link
          
          url = link['href']
          next unless url && url.match?(/\.onion/)

          title = result.at_css('.result__title')&.text&.strip || ''
          description = result.at_css('.result__snippet')&.text&.strip || ''

          results << SearchResult.new(
            url: url,
            title: title,
            description: description,
            engine: 'duckduckgo'
          )
        end

        # Fallback to any onion links if no structured results found
        if results.empty?
          doc.css('a').each do |link|
            href = link['href']
            next unless href && href.match?(/\.onion/)

            results << SearchResult.new(
              url: href,
              title: link.text.strip,
              description: '',
              engine: 'duckduckgo'
            )
          end
        end

        results
      end

      def cleanup_browser(browser)
        browser.quit
      rescue => e
        @logger.warn("Failed to cleanup browser: #{e.message}")
      end
    end
  end
end