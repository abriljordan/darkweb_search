require_relative 'base_engine'
require 'ferrum'
require 'nokogiri'

module DarkWebSearch
  module SearchEngines
    class AhmiaSearchEngine < BaseSearchEngine
      def initialize
        super
        @base_url = Config.settings[:engines]['ahmia'][:url]
      end

      def search(query)
        @logger.info("Starting Ahmia search for query: #{query}")
        browser = setup_browser
        
        begin
          results = fetch_results(browser, query)
          @logger.info("Found #{results.size} results from Ahmia")
          results
        rescue SearchError => e
          @logger.error("Ahmia search failed: #{e.message}")
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
            'proxy-server': "socks5://#{Config.settings[:tor][:proxy_host]}:#{Config.settings[:tor][:proxy_port]}"
          },
          timeout: Config.settings[:search][:timeout]
        )
      rescue => e
        @logger.error("Failed to initialize browser: #{e.message}")
        raise SearchError, "Browser initialization failed: #{e.message}"
      end

      def fetch_results(browser, query)
        url = "#{@base_url}#{URI.encode_www_form_component(query)}"
        @logger.debug("Navigating to: #{url}")
        
        browser.go_to(url)
        browser.network.wait_for_idle
        sleep 2 # Allow JavaScript execution

        parse_results(browser.body)
      rescue => e
        raise SearchError, "Failed to fetch results: #{e.message}"
      end

      def parse_results(html)
        doc = Nokogiri::HTML(html)
        results = Set.new

        doc.css("div#content li.result").each do |result|
          link = result.css('a').first
          next unless link

          href = link.attr('href')
          next unless href&.match?(/\.onion/)

          results << SearchResult.new(
            url: href,
            title: link.text.strip,
            description: result.css('p.description').first&.text&.strip,
            engine: 'ahmia'
          )
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