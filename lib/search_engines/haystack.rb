require_relative 'base_engine'
require 'nokogiri'
require 'uri'

module DarkWebSearch
  module SearchEngines
    class HaystackSearchEngine < BaseSearchEngine
      # Current Haystack mirrors with HTTPS
      HAYSTACK_URLS = [
        "https://haystak5njsmn2hqkewecpaxetahtwhsbsa64jom2k22z5afxhnpxfid.onion",
        "https://haystack.onion",
        "https://haystaclxdqc43vn.onion"
      ]

      def initialize
        super
        @base_url = find_working_mirror
      end

      def search(query)
        @logger.info("Starting Haystack search for query: #{query}")
        return Set.new unless @base_url # Skip if no working mirror found
        
        begin
          formatted_query = URI.encode_www_form_component(query)
          url = "#{@base_url}/search/#{formatted_query}"
          @logger.debug("Querying: #{url}")
          
          response = get_response_with_retry(url)
          results = ensure_set(parse_results(response.body))
          
          @logger.info("Found #{results.size} results from Haystack")
          results
        rescue SearchError => e
          @logger.error("Haystack search failed: #{e.message}")
          Set.new
        end
      end

      private

      def find_working_mirror
        HAYSTACK_URLS.each do |url|
          begin
            @logger.debug("Testing Haystack mirror: #{url}")
            response = get_response_with_retry("#{url}/", retries: 1)
            if response.is_a?(Net::HTTPSuccess)
              @logger.info("Found working Haystack mirror: #{url}")
              return url
            end
          rescue => e
            @logger.debug("Mirror #{url} failed: #{e.message}")
            next
          end
        end
        @logger.warn("No working Haystack mirrors found")
        nil
      end

      def get_response_with_retry(url, retries: 3)
        attempts = 0
        begin
          attempts += 1
          get_response(url)
        rescue SearchError => e
          if attempts < retries
            sleep(2 ** attempts) # Exponential backoff
            retry
          else
            raise
          end
        end
      end

      def parse_results(html)
        doc = Nokogiri::HTML(html)
        results = []
        seen_urls = Set.new

        # Try multiple selectors for results
        selectors = [
          '.search-result',
          '.result',
          '.tor-result',
          '.onion-result'
        ]

        selectors.each do |selector|
          doc.css(selector).each do |result|
            link = result.at_css('h3 a, h4 a, .title a, a.title, a[href*=".onion"]')
            next unless link

            url = extract_onion_url(link['href'])
            next unless url && url.match?(/\.onion/) && !seen_urls.include?(url)
            
            seen_urls.add(url)
            title = link.text.strip
            description = result.at_css('.description, .snippet, .text')&.text&.strip

            results << SearchResult.new(
              url: url,
              title: title || url,
              description: description,
              engine: 'haystack'
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
              engine: 'haystack'
            )
          end
        end

        results
      end

      def extract_onion_url(href)
        return nil unless href
        
        # Handle redirect URLs
        if href.include?('redirect=') || href.include?('url=')
          uri = URI.parse(href)
          params = URI.decode_www_form(uri.query || '').to_h
          redirect_url = params['redirect'] || params['url']
          return redirect_url if redirect_url&.include?('.onion')
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
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = 120
        http.read_timeout = 120
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.get(uri.request_uri)
      rescue => e
        @logger.error("Failed to get response: #{e.message}")
        raise SearchError, "Failed to get response: #{e.message}"
      end

      def ensure_set(obj)
        obj.is_a?(Set) ? obj : Set.new(obj)
      end
    end
  end
end