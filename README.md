## Project Development
This project was developed using modern AI pair programming techniques, demonstrating:
- Effective use of AI coding assistants
- Code review and enhancement
- Security-focused implementation
- Debugging and optimization

# 🔍 Dark Web Intelligence Tool (Collaborative AI Project)

> Last Updated: May 2025

A sophisticated OSINT tool for dark web research, developed using modern AI pair programming techniques.

## 🌟 Key Highlights

- 🤖 Developed using modern AI pair programming
- 🔒 Security-focused implementation
- 🧪 Thoroughly tested and optimized
- 📚 Well-documented codebase

## ✨ Features

- 🔍 Advanced Boolean keyword search (AND, OR, exact phrases)
- 🌐 Dark web (.onion) search engine integration
- 💾 Export results to TXT or CSV formats
- 🔌 Modular search engine architecture
- 📊 Clean CLI interface with intuitive guidance
- 🔐 Built-in Tor network integration

## 🚀 Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/darkweb_search.git

# Navigate to project directory
cd darkweb_search

# Install dependencies
bundle install
```

## 📖 Usage

Basic usage example:
```bash
ruby darkweb_search.rb -q "bitcoin AND market" -e ahmia -o results.txt
```

### CLI Options

| Option | Description |
|--------|-------------|
| `-q` | Query string (Boolean logic supported) |
| `-e` | Search engine (ahmia, torch, haystak, all) |
| `-o` | Output file path |
| `-t` | Route via Tor (required for .onion engines) |
| `-h` | Display help information |

## 🔧 Requirements

- Ruby 3.x or higher
- Bundler (`gem install bundler`)
- Tor service (for .onion access)
- curl

## 📁 Project Structure

```
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
└── test/
    ├── integration/
    └── lib/
```

## 📝 Example Searches

Search Ahmia engine:
```bash
ruby darkweb_search.rb -q "bitcoin AND market" -e ahmia
```

Search all engines via Tor:
```bash
ruby darkweb_search.rb -q "gmail AND password" -e all -t -o results.txt
```

## ⚠️ Disclaimer

⚠️ For educational and ethical research only. Ensure compliance with applicable laws in your country.

## 👤 Author

Created by Abril Jordan Casinillo

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---
Made with ❤️ and ☕