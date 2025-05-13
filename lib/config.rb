require 'yaml'
require 'logger'

module DarkWebSearch
  class Config
    class << self
      attr_accessor :settings, :logger

      def load(config_file = 'config.yml')
        @settings = default_settings.merge(load_yaml(config_file))
        setup_logger
        @settings
      end

      def setup_logger
        @logger = Logger.new(@settings[:log_file])
        @logger.level = Logger.const_get(@settings[:log_level].upcase)
        @logger.formatter = proc do |severity, datetime, progname, msg|
          "[#{datetime}] #{severity}: #{msg}\n"
        end
      end

      private

      def default_settings
        {
          tor: {
            proxy_host: '127.0.0.1',
            proxy_port: 9050,
            control_port: 9051,
            circuit_refresh_interval: 600 # 10 minutes
          },
          search: {
            concurrent: true,
            timeout: 60,
            max_retries: 3,
            retry_delay: 5,
            rate_limit: 2 # requests per second
          },
          engines: {
            'ahmia' => {
              enabled: true,
              url: 'http://juhanurmihxlp77nkq76byazcldy2hlmovfu2epvl5ankdibsot4csyd.onion/search/?q='
            },
            'duckduckgo' => {
              enabled: true,
              url: 'https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/'
            },
            'haystack' => {
              enabled: true,
              url: 'http://haystak5njsmn2hqkewecpaxetahtwhsbsa64jom2k22z5afxhnpxfid.onion/search?q='
            },
            'torch' => {
              enabled: true,
              url: 'http://xmh57jrknzkhv6y3ls3ubitzfqnkrwxhopf5aygthi7d6rplyvk3noyd.onion/search?query='
            }
          },
          log_file: 'darkweb_search.log',
          log_level: 'info',
          results_dir: 'results'
        }
      end

      def load_yaml(file)
        YAML.load_file(file)
      rescue Errno::ENOENT
        {} # Return empty hash if config file doesn't exist
      end
    end
  end
end
