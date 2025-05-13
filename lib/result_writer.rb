class ResultWriter
    def self.save(filename, results)
        return unless filename

        File.open(filename, 'w') do |file|
            results.each { |line| file.puts(line) }
        end
        puts "[+] Results saved to '#{filename}'."
    rescue => e
        puts "[!] Error saving results: #{e.message}"
        exit 1
    end
end