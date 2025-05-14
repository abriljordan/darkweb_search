require 'logger'

module DarkWebSearch
  class Config
    class << self
      def settings
        @settings ||= {
          tor: {
            proxy_host: '127.0.0.1',
            proxy_port: 9050
          },
          search: {
            rate_limit: 1,  # Requests per second
            timeout: 30,    # Request timeout in seconds
            max_retries: 3  # Maximum number of retries per request
          },
          output: {
            format: 'text',
            file: nil
          }
        }
      end

      def logger
        @logger ||= begin
          logger = Logger.new('darkweb_search.log')
          logger.level = Logger::INFO
          logger.formatter = proc do |severity, datetime, progname, msg|
            "[#{datetime}] #{severity}: #{msg}\n"
          end
          logger
        end
      end

      def load(config_file = nil)
        if config_file && File.exist?(config_file)
          begin
            file_settings = YAML.load_file(config_file)
            @settings = settings.merge(file_settings)
          rescue => e
            logger.error("Failed to load config file: #{e.message}")
          end
        end
        @settings
      end
    end
  end
end
