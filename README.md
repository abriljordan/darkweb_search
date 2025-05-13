
## Project Development
This project was developed using modern AI pair programming techniques, demonstrating:
- Effective use of AI coding assistants
- Code review and enhancement
- Security-focused implementation
- Debugging and optimization

# 🔍 DDark Web Intelligence Tool (Collaborative AI Project)

• Architected and implemented a Ruby-based OSINT tool using modern AI pair programming
• Enhanced and debugged AI-generated code for Tor network integration
• Demonstrated ability to work with and improve AI-generated solutions
• Applied critical thinking to ensure secure and reliable implementation

## Features

- ✅ Boolean keyword search (AND, OR, exact phrases)
- ✅ Supports dark web (.onion) search engines
- ✅ Save results to TXT or CSV file
- ✅ Modular engine support (easily add more)
- ✅ Clean CLI interface with helpful guidance

## Installation

```bash
git clone https://github.com/yourusername/darkweb_search.git
cd darkweb-search-cli
bundle install

Usage

ruby darkweb_search.rb -q "bitcoin AND market" -e ahmia -o results.txt

CLI Options

Option	Description
-q	Query string (Boolean logic supported)
-e	Search engine (ahmia, torch, haystak, all)
-o	Output file path
-t	Route via Tor (optional, required for .onion engines)
-h, --help	Display usage instructions

Requirements
	•	Ruby 3.x
	•	Bundler (gem install bundler)
	•	Tor service (optional, for .onion engines)
	•	curl

Project Structure

```bash
darkweb_search/
├── Gemfile
├── Gemfile.lock
├── README.md
├── darkweb_search.rb
├── lib/
│   ├── cli_parser.rb
│   ├── result_writer.rb
│   ├── search_engines/
│   │   ├── ahmia.rb
│   │   ├── base_engine.rb
│   │   ├── duckduckgo.rb
│   │   ├── haystack.rb
│   │   └── torch.rb
│   └── tor_manager.rb
├── results.txt
└── test/
    ├── integration/
    │   ├── search_test.rb
    │   └── [various test result files]
    └── lib/
        ├── cli_parser_test.rb
        ├── search_engines/
        └── tor_manager_test.rb
```

Example Searches
	•	Search Ahmia for “bitcoin AND market”:

ruby darkweb_search.rb -q "bitcoin AND market" -e ahmia


	•	Search all engines via Tor and save to file:

ruby darkweb_search.rb -q "gmail AND password" -e all -t -o results.txt



Disclaimer

⚠️ For educational and ethical research only. Ensure compliance with applicable laws in your country.

Credits

Created by Abril Jordan Casinillo
Developed during cybersecurity R&D and some serious late-night “vibe coding” sessions.

⸻