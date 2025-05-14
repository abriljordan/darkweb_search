# Dark Web Search Tool 🔍

A secure and user-friendly Ruby tool for searching the dark web through Tor. This tool provides both an interactive menu interface and a command-line interface for searching multiple dark web search engines.

## 🌟 Features

- 🔒 Secure searching through Tor network
- � Multiple dark web search engines (Ahmia, Torch)
- 📊 Smart result ranking and filtering
- � Automatic result saving with timestamps
- 📜 Search history tracking
- 🔍 Boolean search operators (AND, OR, NOT)
- 🖥️ Interactive menu interface
- � Command-line interface
- ⚡ Parallel search execution
- 🔐 Built-in safety features

## � Installation

1. Ensure you have Ruby installed (2.7 or higher)
2. Install Tor and ensure it's running (default: localhost:9050)
3. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/darkweb_search.git
   cd darkweb_search
   ```
4. Install dependencies:
   ```bash
   bundle install
   ```

## � Usage

### Interactive Mode

Run the tool in interactive mode:
```bash
ruby darkweb_search.rb -i
```

The interactive menu provides these options:
1. 🔍 Perform a search
2. 📜 View recent searches
3. 💡 Show search tips
4. 🌐 Check Tor connection
5. ⚙️ Show settings
q. Quit

### Command-Line Mode

Basic search:
```bash
ruby darkweb_search.rb "your search query"
```

With options:
```bash
ruby darkweb_search.rb -o results.txt "bitcoin AND wallet"
```

Available options:
```
-h, --help     Show help message
-i            Interactive mode
-o FILE       Save results to FILE (default: results_TIMESTAMP.txt)
-v            Verbose output
-q            Quiet mode
```

### Search Tips

1. Boolean Operators:
   ```
   AND: "bitcoin AND wallet"    (requires both terms)
   OR:  "bitcoin OR ethereum"   (either term)
   NOT: "bitcoin NOT scam"      (excludes term)
   ```

2. Phrase Search:
   ```
   "exact phrase search"        (matches exact phrase)
   ```

3. Best Practices:
   - Be specific in your queries
   - Use multiple related terms
   - Try alternative spellings
   - Start broad, then narrow down

## 📁 Project Structure

```
darkweb_search/
├── darkweb_search.rb     # Main application
├── Gemfile              # Dependencies
├── lib/
│   ├── config.rb       # Configuration
│   └── search_engines/
│       ├── ahmia.rb    # Ahmia search engine
│       ├── base_engine.rb  # Base search engine class
│       └── torch.rb    # Torch search engine
└── results/            # Search results directory
```

## � Safety Features

- All searches are routed through Tor
- Results are saved locally
- No direct website access
- Built-in safety warnings
- Automatic URL sanitization

## ⚠️ Safety Warnings

1. NEVER download files from .onion sites
2. NEVER enter credentials on dark web sites
3. Use Tor Browser for actually visiting sites
4. Don't click links directly
5. Keep your system updated

## 📝 Results

- All results are saved to the `results/` directory
- Each search creates a timestamped file
- Results include:
  - Title
  - URL
  - Description (when available)
  - Source engine
  - Timestamp

## �️ Configuration

Default configuration can be modified in `lib/config.rb`:
- Tor proxy settings
- Rate limiting
- Retry attempts
- Search engine options

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚠️ Disclaimer

This tool is for research purposes only. Be careful when accessing the dark web and always follow applicable laws and regulations.