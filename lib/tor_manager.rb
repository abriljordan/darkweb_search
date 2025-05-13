require 'socksify'
require 'socksify/http'
require 'open3'
require 'fileutils' 
require 'uri' 
require 'net/http' 
require 'ferrum'
require 'socket'

module DarkWebSearch
  class TorManager
    TOR_PROXY_HOST = '127.0.0.1'
    TOR_PROXY_PORT = 9050
    TOR_CONTROL_PORT = 9051
    STARTUP_TIMEOUT = 30
    
    class << self
      attr_accessor :tor_process, :browser
    end

    def self.enable_tor_proxy
      unless tor_installed?
        puts "[!] Tor is not installed. Please install Tor first:"
        puts "    Mac: brew install tor"
        puts "    Linux: sudo apt-get install tor"
        return false
      end

      # Check if Tor is already running through brew services
      if system("pgrep -x tor > /dev/null")
        puts "[+] Tor is already running"
      else
        start_tor_service
      end

      if verify_tor_connection
        setup_browser
        true
      else
        disable_tor
        false
      end
    rescue => e
      puts "[!] Error enabling Tor proxy: #{e.message}"
      disable_tor
      false
    end

    def self.start_tor_service
      puts "[*] Starting Tor..."
      
      # Try to start tor through brew services first
      if system("which brew > /dev/null 2>&1")
        system("brew services start tor")
        sleep 5  # Give some time for the service to start
      end

      # If brew services didn't work, try direct startup
      unless tor_enabled?
        config = create_tor_config
        tor_path = find_tor_binary
        
        unless tor_path
          puts "[!] Could not find tor executable"
          return false
        end

        self.tor_process = IO.popen("#{tor_path} -f #{config}")
        wait_for_tor_startup
      end
    end

    def self.find_tor_binary
      tor_paths = [
        '/opt/homebrew/bin/tor',  # Homebrew on Apple Silicon
        '/usr/local/bin/tor',     # Homebrew on Intel Mac
        '/usr/bin/tor',           # Linux default
        'tor'                     # System PATH
      ]

      tor_paths.find { |path| system("which #{path} > /dev/null 2>&1") }
    end

    def self.create_tor_config
      config_path = File.join(Dir.pwd, 'tor_config')
      File.open(config_path, 'w') do |f|
        f.puts "SocksPort #{TOR_PROXY_PORT}"
        f.puts "ControlPort #{TOR_CONTROL_PORT}"
        f.puts "DataDirectory #{File.join(Dir.pwd, 'tor_data')}"
        f.puts "Log notice stdout"
      end
      config_path
    end

    def self.wait_for_tor_startup
      start_time = Time.now
      
      while Time.now - start_time < STARTUP_TIMEOUT
        if tor_enabled?
          puts "[+] Tor service started successfully"
          return true
        end
        print "."
        sleep 1
      end
      
      puts "\n[!] Tor service failed to start within #{STARTUP_TIMEOUT} seconds"
      false
    end

    def self.verify_tor_connection
      puts "[*] Verifying Tor connection..."
      retries = 3
      retry_delay = 2

      retries.times do |i|
        begin
          socket = TCPSocket.new(TOR_PROXY_HOST, TOR_PROXY_PORT)
          socket.close
          puts "[+] SOCKS proxy is responding"
          
          # Verify we're actually using Tor
          uri = URI('https://check.torproject.org/api/ip')
          Net::HTTP.SOCKSProxy(TOR_PROXY_HOST, TOR_PROXY_PORT).start(uri.host, uri.port, use_ssl: true) do |http|
            response = http.get(uri.path)
            if response.code == "200" && response.body.include?("IsTor")
              puts "[+] Successfully connected to Tor network"
              return true
            end
          end
        rescue => e
          puts "[!] Attempt #{i + 1}/#{retries}: #{e.message}"
          sleep retry_delay
        end
      end

      puts "[!] Failed to verify Tor connection"
      false
    end

    def self.setup_browser
      self.browser = Ferrum::Browser.new(
        browser_options: {
          'no-sandbox': nil,
          'proxy-server': "socks5://#{TOR_PROXY_HOST}:#{TOR_PROXY_PORT}"
        },
        timeout: 60
      )
    end

    def self.tor_installed?
      system("which tor > /dev/null 2>&1")
    end

    def self.tor_enabled?
      begin
        socket = TCPSocket.new(TOR_PROXY_HOST, TOR_PROXY_PORT)
        socket.close
        true
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EPERM
        false
      end
    end

    def self.disable_tor
      if browser
        begin
          browser.quit
        rescue => e
          puts "[!] Error closing browser: #{e.message}"
        ensure
          self.browser = nil
        end
      end

      if tor_process
        begin
          Process.kill("TERM", tor_process.pid)
          Process.wait(tor_process.pid)
          puts "[*] Tor process terminated"
        rescue Errno::ESRCH, Errno::ECHILD => e
          puts "[!] Tor process already terminated: #{e.message}"
        rescue => e
          puts "[!] Error terminating Tor process: #{e.message}"
        ensure
          self.tor_process = nil
        end
      end

      # Clean up temporary files
      FileUtils.rm_f('tor_config')
      FileUtils.rm_rf('tor_data')
    end
  end
end