require_relative 'base_engine'
require 'nokogiri'
require 'uri'

module DarkWebSearch
  module SearchEngines
    class DuckDuckGoSearchEngine < BaseSearchEngine
      # Current official DuckDuckGo onion address
      DUCKDUCKGO_URL = "https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion"

      def initialize
        super
        @base_url = DUCKDUCKGO_URL
      end

      def search(query)
        @logger.info("Starting DuckDuckGo search for query: #{query}")
        
        begin
          # Format query to specifically look for .onion sites
          formatted_query = "#{query} site:.onion"
          url = "#{@base_url}/html/?q=#{URI.encode_www_form_component(formatted_query)}&kl=wt-wt"
          @logger.debug("Querying: #{url}")
          
          response = get_response(url)
          results = ensure_set(parse_results(response.body))
          
          @logger.info("Found #{results.size} results from DuckDuckGo")
          results
        rescue SearchError => e
          @logger.error("DuckDuckGo search failed: #{e.message}")
          Set.new
        end
      end

      private

      def parse_results(html)
        doc = Nokogiri::HTML(html)
        results = []
        seen_urls = Set.new

        # Try multiple selectors for the HTML version
        selectors = [
          '.result__body', # Main results
          '.results_links_deep', # Alternative results
          '.web-result' # Another possible class
        ]

        selectors.each do |selector|
          doc.css(selector).each do |result|
            # Try multiple link selectors
            link = result.at_css('.result__title a, .result__a, a.result__url')
            next unless link

            url = extract_onion_url(link['href'])
            next unless url && url.match?(/\.onion/) && !seen_urls.include?(url)
            
            seen_urls.add(url)
            title = link.text.strip
            
            # Try multiple description selectors
            description = nil
            desc_selectors = [
              '.result__snippet',
              '.result__abstract',
              '.result-snippet',
              '.result__description'
            ]
            
            desc_selectors.each do |desc_selector|
              if (desc_elem = result.at_css(desc_selector))
                description = desc_elem.text.strip
                break
              end
            end

            results << SearchResult.new(
              url: url,
              title: title || url,
              description: description,
              engine: 'duckduckgo'
            )
          end
          
          break if results.any? # Stop if we found results with current selector
        end

        # Fallback: look for any .onion links
        if results.empty?
          doc.css('a[href*=".onion"]').each do |link|
            url = extract_onion_url(link['href'])
            next unless url && url.match?(/\.onion/) && !seen_urls.include?(url)
            
            seen_urls.add(url)
            results << SearchResult.new(
              url: url,
              title: link.text.strip || url,
              description: nil,
              engine: 'duckduckgo'
            )
          end
        end
        
        results
      end

      def extract_onion_url(href)
        return nil unless href
        
        # Handle DuckDuckGo's redirect URLs
        if href.include?('/l/?uddg=') || href.include?('duckduckgo.com/l/?uddg=')
          uri = URI.parse(href)
          params = URI.decode_www_form(uri.query || '').to_h
          decoded_url = URI.decode_www_form_component(params['uddg']) if params['uddg']
          return decoded_url if decoded_url&.include?('.onion')
        end
        
        # If it's a direct .onion URL
        if href.include?('.onion')
          # Handle relative URLs
          if href.start_with?('/')
            URI.join(@base_url, href).to_s
          else
            href
          end
        end
      rescue URI::Error => e
        @logger.debug("Failed to parse URL #{href}: #{e.message}")
        nil
      end
    end
  end
end