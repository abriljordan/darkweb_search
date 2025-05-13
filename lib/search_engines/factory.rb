require_relative '../config'
require_relative 'ahmia'
require_relative 'duckduckgo'
require_relative 'haystack'
require_relative 'torch'

module DarkWebSearch
  module SearchEngines
    class Factory
      class << self
        def create(engine_name)
          config = Config.settings
          engine_config = config[:engines][engine_name]
          
          return nil unless engine_config && engine_config[:enabled]

          case engine_name.downcase
          when 'ahmia'
            DarkWebSearch::SearchEngines::AhmiaSearchEngine.new
          when 'duckduckgo'
            DarkWebSearch::SearchEngines::DuckDuckGoSearchEngine.new
          when 'haystack'
            DarkWebSearch::SearchEngines::HaystackSearchEngine.new
          when 'torch'
            DarkWebSearch::SearchEngines::TorchSearchEngine.new
          else
            Config.logger.warn("Unknown search engine: #{engine_name}")
            nil
          end
        end

        def create_enabled_engines
          Config.settings[:engines]
            .select { |_, config| config[:enabled] }
            .keys
            .map { |name| create(name) }
            .compact
        end

        def create_engines(selected_engines)
          engines = []
          
          selected_engines.each do |engine_name|
            case engine_name.downcase
            when 'ahmia'
              engines << DarkWebSearch::SearchEngines::AhmiaSearchEngine.new
            when 'torch'
              engines << DarkWebSearch::SearchEngines::TorchSearchEngine.new
            when 'haystack'
              engines << DarkWebSearch::SearchEngines::HaystackSearchEngine.new
            when 'duckduckgo'
              engines << DarkWebSearch::SearchEngines::DuckDuckGoSearchEngine.new
            else
              Config.logger.warn("Unknown search engine: #{engine_name}")
            end
          end

          if engines.empty?
            Config.logger.warn("No valid search engines selected. Using default (Ahmia)")
            engines << DarkWebSearch::SearchEngines::AhmiaSearchEngine.new
          end

          engines
        end
      end
    end

    class SearchResult
      attr_reader :url, :title, :description, :engine, :timestamp

      def initialize(url:, title: nil, description: nil, engine:)
        @url = url
        @title = title
        @description = description
        @engine = engine
        @timestamp = Time.now
      end

      def to_h
        {
          url: @url,
          title: @title,
          description: @description,
          engine: @engine,
          timestamp: @timestamp
        }
      end

      def ==(other)
        return false unless other.is_a?(SearchResult)
        url == other.url
      end

      def hash
        url.hash
      end

      def eql?(other)
        self == other
      end
    end
  end
end
