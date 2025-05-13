require_relative '../config'
require 'net/http'
require 'uri'
require 'timeout'

module DarkWebSearch
  module SearchEngines
    class BaseSearchEngine
      class SearchError < StandardError; end
      
      def initialize
        @config = Config.settings
        @logger = Config.logger
        @rate_limiter = RateLimiter.new(@config[:search][:rate_limit])
      end

      def search(query)
        raise NotImplementedError, "#{self.class} must implement search method"
      end

      protected

      def get_response(url, options = {})
        retries = 0
        begin
          @rate_limiter.wait

          Timeout.timeout(@config[:search][:timeout]) do
            uri = URI(url)
            response = Net::HTTP.get_response(uri)
            
            case response
            when Net::HTTPSuccess
              response
            else
              raise SearchError, "HTTP request failed with status #{response.code}"
            end
          end
        rescue URI::InvalidURIError => e
          @logger.error("Invalid URL format: #{e.message}")
          raise SearchError, "Invalid URL format: #{e.message}"
        rescue Timeout::Error => e
          @logger.error("Request timed out: #{e.message}")
          retry if should_retry?(retries += 1)
          raise SearchError, "Request timed out after #{retries} attempts"
        rescue SocketError => e
          @logger.error("Network connection failed: #{e.message}")
          retry if should_retry?(retries += 1)
          raise SearchError, "Network connection failed after #{retries} attempts"
        rescue => e
          @logger.error("Unexpected error: #{e.message}")
          retry if should_retry?(retries += 1)
          raise SearchError, "Search failed after #{retries} attempts: #{e.message}"
        end
      end

      private

      def should_retry?(current_retries)
        if current_retries < @config[:search][:max_retries]
          sleep(@config[:search][:retry_delay])
          true
        else
          false
        end
      end
    end

    class RateLimiter
      def initialize(requests_per_second)
        @interval = 1.0 / requests_per_second
        @last_request = Time.now - @interval
      end

      def wait
        elapsed = Time.now - @last_request
        sleep(@interval - elapsed) if elapsed < @interval
        @last_request = Time.now
      end
    end
  end
end
