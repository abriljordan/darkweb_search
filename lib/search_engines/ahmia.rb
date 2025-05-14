require_relative 'base_engine'
require 'nokogiri'
require 'uri'

module DarkWebSearch
  module SearchEngines
    class AhmiaSearchEngine < BaseSearchEngine
      # Current Ahmia onion address
      AHMIA_URL = "http://juhanurmihxlp77nkq76byazcldy2hlmovfu2epvl5ankdibsot4csyd.onion"
      MAX_RESULTS = 100 # Limit to most relevant results

      def initialize
        super
        @base_url = AHMIA_URL
      end

      def search(query)
        @logger.info("Starting Ahmia search for query: #{query}")
        
        begin
          url = "#{@base_url}/search/?q=#{URI.encode_www_form_component(query)}"
          @logger.debug("Querying: #{url}")
          
          response = get_response(url)
          results = ensure_set(parse_results(response.body, query))
          
          @logger.info("Found #{results.size} results from Ahmia")
          results
        rescue SearchError => e
          @logger.error("Ahmia search failed: #{e.message}")
          Set.new
        end
      end

      private

      def parse_results(html, query)
        doc = Nokogiri::HTML(html)
        results = []
        seen_urls = Set.new
        query_terms = query.downcase.split(/\s+AND\s+|\s+OR\s+|\s+NOT\s+|\s+/)

        # Try multiple selectors for results
        selectors = [
          '.result',
          '.ahmia-result',
          '.onion-result'
        ]

        selectors.each do |selector|
          doc.css(selector).each do |result|
            # Extract title and description
            title_elem = result.at_css('h4, h3, .title')
            next unless title_elem
            title = title_elem.text.strip

            # Try to find the direct .onion URL
            onion_link = result.css('a').find { |a| a['href']&.include?('.onion') }
            next unless onion_link

            # Extract the actual .onion URL
            url = extract_onion_url(onion_link['href'])
            next unless url && !seen_urls.include?(url)
            
            seen_urls.add(url)
            description = result.at_css('.description, .snippet, .text')&.text&.strip

            # Calculate relevance score
            score = calculate_relevance(title, description, query_terms)
            next if score == 0 # Skip completely irrelevant results

            results << {
              result: SearchResult.new(
                url: url,
                title: title || url,
                description: description,
                engine: 'ahmia'
              ),
              score: score
            }
          end

          break if results.any? # Stop if we found results with current selector
        end

        # Sort by relevance and take top results
        results.sort_by { |r| -r[:score] }
              .take(MAX_RESULTS)
              .map { |r| r[:result] }
      end

      def calculate_relevance(title, description, query_terms)
        score = 0
        return 0 unless title # Must have a title

        # Convert to lowercase for comparison
        title = title.downcase
        description = description&.downcase || ""

        query_terms.each do |term|
          # Higher weight for terms in title
          score += 3 if title.include?(term)
          score += 1 if description.include?(term)
        end

        # Bonus points for .onion domains in title
        score += 2 if title.include?('.onion')

        # Penalty for very short or very long titles
        score -= 1 if title.length < 10 || title.length > 100

        # Penalty for missing description
        score -= 1 if description.empty?

        # Bonus for descriptions with good length
        score += 1 if description.length.between?(50, 300)

        # Additional relevance checks
        score -= 2 if title =~ /404|not found|error/i
        score -= 1 if description =~ /404|not found|error/i

        # Ensure non-negative score
        [score, 0].max
      end

      def extract_onion_url(href)
        return nil unless href

        # Handle Ahmia redirect URLs
        if href.include?('/search/redirect')
          uri = URI.parse(href)
          params = URI.decode_www_form(uri.query || '').to_h
          return params['redirect_url'] if params['redirect_url']&.include?('.onion')
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

      def get_response(url)
        uri = URI(url)
        
        # Configure SOCKS proxy for Tor
        proxy_host = Config.settings[:tor][:proxy_host]
        proxy_port = Config.settings[:tor][:proxy_port]
        
        # Use socksify-http for proper SOCKS proxy support
        Net::HTTP.SOCKSProxy(proxy_host, proxy_port).start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.open_timeout = 120
          http.read_timeout = 120
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          
          response = http.get(uri.request_uri)
          
          case response
          when Net::HTTPSuccess
            response
          else
            raise SearchError, "HTTP request failed with status #{response.code}"
          end
        end
      rescue => e
        @logger.error("Failed to get response: #{e.message}")
        raise SearchError, "Failed to get response: #{e.message}"
      end
    end
  end
end