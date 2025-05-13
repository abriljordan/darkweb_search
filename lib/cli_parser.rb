require 'optparse'

class CLIParser
  AVAILABLE_ENGINES = {
    'ahmia' => 'Ahmia Search Engine',
    'torch' => 'Torch Search Engine',
    'haystack' => 'Haystack Search Engine',
    'duckduckgo' => 'DuckDuckGo .onion Search'
  }

  def self.parse(args)
    options = {
      engines: ['ahmia']  # Default engine
    }

    opt_parser = OptionParser.new do |opts|
      opts.banner = show_banner

      # Define command line options
      opts.on("-qQUERY", "--query=QUERY", "Search query string") do |q|
        # Add validation for empty or nil query
        if q.nil? || q.strip.empty?
          puts "[!] Please provide a valid search query."
          exit 1
        end
        options[:query] = q
      end

      opts.on("-eENGINES", "--engines=ENGINES", Array,
              "Comma-separated list of search engines to use (#{AVAILABLE_ENGINES.keys.join(', ')})") do |engines|
        invalid_engines = engines - AVAILABLE_ENGINES.keys
        if invalid_engines.any?
          puts "[!] Invalid engine(s): #{invalid_engines.join(', ')}"
          puts "[!] Available engines: #{AVAILABLE_ENGINES.keys.join(', ')}"
          exit 1
        end
        options[:engines] = engines
      end

      opts.on("-t", "--tor", "Route through Tor") do
        options[:tor] = true
      end

      opts.on("-oFILE", "--output=FILE", "Output results to file") do |file|
        options[:output] = file
      end

      opts.on("-h", "--help", "Show this help message") do
        puts show_banner
        puts show_help
        exit
      end

      opts.on("--list-engines", "List available search engines and their descriptions") do
        puts "\nAvailable Search Engines:"
        puts "========================"
        AVAILABLE_ENGINES.each do |key, desc|
          puts "#{key.ljust(12)} - #{desc}"
        end
        exit
      end
    end

    begin
      opt_parser.parse!(args)
    rescue OptionParser::InvalidOption => e
      puts "[!] #{e.message}"
      puts show_help
      exit 1
    end

    # Check if no arguments provided
    if options.empty?
      puts "[!] Missing required arguments."
      puts show_help
      exit 1
    end

    options
  end

  private

  def self.show_banner
    <<-'BANNER'
 ____             _         _      __        __         _     
|  _ \  __ _  ___| | ____ _| |_ ___\ \      / /__  _ __| | __ 
| | | |/ _` |/ __| |/ / _` | __/ _ \\ \ /\ / / _ \| '__| |/ / 
| |_| | (_| | (__|   < (_| | ||  __/ \ V  V / (_) | |  |   <  
|____/ \__,_|\___|_|\_\__,_|\__\___|  \_/\_/ \___/|_|  |_|\_\ 

DarkWeb Boolean Search CLI Tool
    BANNER
  end

  def self.show_help
    <<~HELP

      Usage:
        ruby darkweb_search.rb [options]

      Options:
        -q, --query QUERY        Search query string (REQUIRED)
        -e, --engines LIST       Comma-separated list of search engines (default: ahmia)
        -t, --tor                Route traffic through Tor (OPTIONAL)
        -o, --output FILE        Save results to a file (OPTIONAL)
        -h, --help               Show this help message
            --list-engines       List available search engines

      Available Engines:
        #{AVAILABLE_ENGINES.keys.join(', ')}

      Examples:
        ruby darkweb_search.rb -q "bitcoin AND market"
        ruby darkweb_search.rb -q "hacking" -e torch,ahmia
        ruby darkweb_search.rb -q "password" -e haystack -o results.txt
        ruby darkweb_search.rb -q "credit card" -e ahmia,torch,haystack -t -o found.txt

    HELP
  end
end