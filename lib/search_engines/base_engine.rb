require_relative '../config'
require 'net/http'
require 'uri'
require 'timeout'
require 'socksify'
require 'socksify/http'
require 'set'

module DarkWebSearch
  module SearchEngines
    class BaseSearchEngine
      class SearchError < StandardError; end
      
      def initialize
        @config = Config.settings
        @logger = Config.logger
        @rate_limiter = RateLimiter.new(@config[:search][:rate_limit] || 1)
        @tor_checker = TorChecker.new(@config[:tor][:proxy_host], @config[:tor][:proxy_port])
      end

      def search(query)
        raise NotImplementedError, "#{self.class} must implement search method"
      end

      protected

      def get_response(url)
        retries = 0
        begin
          @rate_limiter.wait

          # Verify Tor connection before making request
          unless @tor_checker.verify_connection
            raise SearchError, "Tor proxy not available or not properly configured"
          end

          Timeout.timeout(10) do # Shorter timeout for initial connection
            uri = URI(url)
            proxy_host = @config[:tor][:proxy_host]
            proxy_port = @config[:tor][:proxy_port]
            
            Net::HTTP.SOCKSProxy(proxy_host, proxy_port).start(uri.host, uri.port, 
              use_ssl: uri.scheme == 'https',
              verify_mode: OpenSSL::SSL::VERIFY_NONE,
              open_timeout: 5,  # Shorter connection timeout
              read_timeout: 15, # Slightly longer read timeout
              ssl_timeout: 5,   # SSL connection timeout
              keep_alive_timeout: 5
            ) do |http|
              request = Net::HTTP::Get.new(uri.request_uri)
              request['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; rv:102.0) Gecko/20100101 Firefox/102.0'
              request['Accept-Language'] = 'en-US,en;q=0.5'
              request['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
              
              response = http.request(request)
              
              case response
              when Net::HTTPSuccess
                response
              else
                raise SearchError, "HTTP request failed with status #{response.code}"
              end
            end
          end
        rescue URI::InvalidURIError => e
          @logger.error("Invalid URL format: #{e.message}")
          raise SearchError, "Invalid URL format: #{e.message}"
        rescue Timeout::Error => e
          @logger.error("Request timed out: #{e.message}")
          retry if should_retry?(retries += 1)
          raise SearchError, "Request timed out after #{retries} attempts"
        rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
          @logger.error("Connection failed: #{e.message}")
          retry if should_retry?(retries += 1, fast_fail: true)
          raise SearchError, "Connection failed after #{retries} attempts: #{e.message}"
        rescue => e
          @logger.error("Unexpected error: #{e.message}")
          retry if should_retry?(retries += 1)
          raise SearchError, "Request failed after #{retries} attempts: #{e.message}"
        end
      end

      private

      def should_retry?(attempts, fast_fail: false)
        max_retries = fast_fail ? 1 : (@config[:search][:max_retries] || 3)
        return false if attempts >= max_retries
        
        # Shorter delays for connection failures
        delay = fast_fail ? 2 : (2 ** attempts)
        sleep(delay)
        true
      end

      def ensure_set(results)
        case results
        when Set
          results
        when Array
          Set.new(results)
        when nil
          Set.new
        else
          Set.new([results].compact)
        end
      end
    end

    class TorChecker
      def initialize(host, port)
        @host = host
        @port = port
        @last_check = 0
        @check_interval = 60 # Check every minute
      end

      def verify_connection
        return true if (Time.now.to_i - @last_check) < @check_interval
        
        begin
          Timeout.timeout(5) do # Short timeout for Tor check
            socket = TCPSocket.new(@host, @port)
            socket.close
            @last_check = Time.now.to_i
            true
          end
        rescue => e
          false
        end
      end
    end

    class RateLimiter
      def initialize(requests_per_second)
        @delay = requests_per_second.zero? ? 0 : 1.0 / requests_per_second
        @last_request = Time.now - @delay
      end

      def wait
        return if @delay.zero?
        
        elapsed = Time.now - @last_request
        sleep(@delay - elapsed) if elapsed < @delay
        @last_request = Time.now
      end
    end
  end
end
