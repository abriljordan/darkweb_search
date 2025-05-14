require_relative 'base_engine'
require 'nokogiri'
require 'uri'

module DarkWebSearch
  module SearchEngines
    class TorchSearchEngine < BaseSearchEngine
      # Current Torch onion addresses - ordered by reliability
      TORCH_URLS = [
        "http://torch5uv3oqm2pdk.onion",  # Most reliable mirror first
        "http://torchdeedp3i2jigzjdmfpn5ttjhthh5wbmda2rr3jvqjg5p77c54dqd.onion",
        "http://torchqsxkllrj2eqaitp5xvcgfeg3g5dr3hr2wnuvnj76bbxkxfiwxqd.onion"
      ]

      MAX_RESULTS = 50 # Limit results for better quality

      def initialize
        super
        @base_url = nil # Will be set during search
        @working_mirror = nil
      end

      def search(query)
        @logger.info("Starting Torch search for query: #{query}")
        
        # Try each mirror until we find one that works
        TORCH_URLS.each do |mirror|
          begin
            # Skip mirrors that failed recently
            next if recently_failed?(mirror)
            
            @base_url = mirror
            @logger.debug("Trying Torch mirror: #{@base_url}")
            
            url = "#{@base_url}/search?query=#{URI.encode_www_form_component(query)}"
            response = get_response(url)
            
            # If we get here, the mirror worked
            @working_mirror = mirror
            mark_mirror_success(mirror)
            
            results = ensure_set(parse_results(response.body, query))
            @logger.info("Found #{results.size} results from Torch")
            return results
          rescue SearchError => e
            mark_mirror_failure(mirror)
            @logger.debug("Mirror #{mirror} failed: #{e.message}")
            next # Try next mirror
          end
        end

        # If we get here, all mirrors failed
        @logger.error("All Torch mirrors failed")
        Set.new
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
          '.search-result',
          'table tr:not(:first-child)' # Torch sometimes uses tables for results
        ]

        selectors.each do |selector|
          doc.css(selector).each do |result|
            # Extract URL and title
            url = nil
            title = nil
            description = nil

            # Handle table-based results
            if result.name == 'tr'
              cells = result.css('td')
              next if cells.empty?
              
              link = cells[0]&.at_css('a')
              if link
                url = extract_onion_url(link['href'])
                title = link.text.strip
              end
              
              description = cells[1]&.text&.strip
            else
              link = result.at_css('a[href*=".onion"]')
              next unless link
              
              url = extract_onion_url(link['href'])
              title = link.text.strip
              description = result.at_css('.description, .snippet, .text')&.text&.strip
            end

            next unless url && !seen_urls.include?(url)
            seen_urls.add(url)

            # Calculate relevance score
            score = calculate_relevance(title, description, query_terms)
            next if score == 0 # Skip irrelevant results

            results << {
              result: SearchResult.new(
                url: url,
                title: title || url,
                description: description,
                engine: 'torch'
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
          score += 3 if title.include?(term)
          score += 1 if description.include?(term)
        end

        # Bonus points for .onion domains
        score += 2 if title.include?('.onion')

        # Penalties
        score -= 1 if title.length < 10 || title.length > 100
        score -= 1 if description.empty?
        score -= 2 if title =~ /404|not found|error/i

        [score, 0].max
      end

      def extract_onion_url(href)
        return nil unless href
        
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

      # Mirror failure tracking
      def mark_mirror_failure(mirror)
        @mirror_failures ||= {}
        @mirror_failures[mirror] = Time.now
      end

      def mark_mirror_success(mirror)
        @mirror_failures&.delete(mirror)
      end

      def recently_failed?(mirror)
        return false unless @mirror_failures&.[](mirror)
        
        # Skip mirror if it failed in the last 5 minutes
        Time.now - @mirror_failures[mirror] < 300
      end
    end
  end
end