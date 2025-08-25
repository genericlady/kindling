# Kindling 🔥

[![CI](https://github.com/yourusername/kindling/actions/workflows/ci.yml/badge.svg)](https://github.com/yourusername/kindling/actions/workflows/ci.yml)
[![Ruby](https://img.shields.io/badge/Ruby-3.2%2B-red)](https://www.ruby-lang.org)
[![GTK](https://img.shields.io/badge/GTK-3.0-blue)](https://www.gtk.org)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

**Kindling** is a lightweight desktop tool written in **Ruby + GTK3** that helps you gather and shape context when working with AI.  

Instead of manually hunting for files and pasting snippets, Kindling lets you:  
- Open a project folder  
- Fuzzy-search across its files (handles 50k+ files smoothly)
- Multi-select only what matters  
- Copy a clean, ASCII-style file tree to your clipboard  

Perfect for building prompts where you need to "prime" the AI with project structure.

---

## ✨ Features (MVP)

- **Open a project folder** – start from your codebase or docs  
- **Fuzzy file search** – type a few characters to quickly find files (< 50ms response time)
- **Multi-select** – pick multiple files at once  
- **Tree preview** – see the hierarchy of your selected files as an ASCII tree  
- **One-click copy** – instantly copy that tree to your clipboard  
- **Include file contents** – optionally include actual file contents with syntax highlighting
- **Smart ignoring** – respects `.gitignore` and automatically skips `.git`, `node_modules`, `.DS_Store` and other noise
- **Enterprise-scale support** – no artificial file limits, handles massive monolithic repositories

### Example output:

**Tree only:**
```
my-project/
├── app/
│   ├── controllers/
│   │   └── users_controller.rb
│   └── models/
│       └── user.rb
├── test/
│   ├── controllers/
│   │   └── users_controller_test.rb
│   └── models/
│       └── user_test.rb
└── Gemfile
```

**With "Include contents" checked:**
```
my-project/
├── app/
│   └── models/
│       └── user.rb
└── Gemfile

## app/models/user.rb
class User < ApplicationRecord
  validates :email, presence: true, uniqueness: true
  has_many :posts
end

## Gemfile

source "https://rubygems.org"
gem "rails", "~> 7.0"
```

---

## 🚀 Getting Started

### Quick Start (< 5 minutes)

#### macOS
```bash
# Install dependencies (2 min)
brew install gtk+3 gobject-introspection pango cairo gdk-pixbuf glib

# Clone and setup (1 min)
git clone https://github.com/yourusername/kindling.git
cd kindling
bundle install

# Run! (< 1 min)
bin/kindling
```

#### Ubuntu/Debian
```bash
# Install dependencies (2 min)
sudo apt update
sudo apt install -y ruby-full ruby-bundler libgtk-3-dev \
  libgirepository1.0-dev libpango1.0-dev libcairo2-dev \
  libgdk-pixbuf2.0-dev libglib2.0-dev

# Clone and setup (1 min)
git clone https://github.com/yourusername/kindling.git
cd kindling
bundle install

# Run! (< 1 min)
bin/kindling
```

📚 **Detailed setup guides**: [macOS](docs/SETUP_MACOS.md) | [Linux](docs/SETUP_LINUX.md)

### System Dependencies (Optional but Recommended)

For blazing-fast indexing of large repositories, Kindling can use Rust-based file search tools:

- **[fd](https://github.com/sharkdp/fd)** (preferred) - A simple, fast alternative to `find`
- **[ripgrep](https://github.com/BurntSushi/ripgrep)** (fallback) - Recursively search directories

Kindling automatically detects these tools if available. Without them, it falls back to a pure Ruby implementation.

#### Installing Search Tools

**macOS:**
```bash
brew install fd ripgrep
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install fd-find ripgrep
# Note: 'fd' is installed as 'fdfind' on Debian/Ubuntu - Kindling detects both
```

**Fedora:**
```bash
sudo dnf install fd-find ripgrep
```

**Windows (with Scoop):**
```powershell
scoop install fd ripgrep
```

### Usage

```bash
# Run the app
bin/kindling

# Show version
bin/kindling --version

# Enable debug output
bin/kindling --debug

# Show help
bin/kindling --help

# Run tests
rake test

# Run benchmarks
rake bench
```

### Configuration for Large/Enterprise Repositories

Kindling uses smart backends and streaming to handle massive monolithic repositories efficiently.

```bash
# Backend selection (default: auto)
export KINDLING_INDEX_BACKEND=auto  # auto, fd, rg, none (force Ruby)

# File limits (default: 500,000)
export KINDLING_MAX_FILES=1000000  # Set to 0 for unlimited

# Memory limit in MB (default: 2000)
export KINDLING_MAX_MEMORY_MB=4000

# Directory pruning (defaults: 250MB, 15000 files)
export KINDLING_MAX_DIR_SIZE_MB=500   # Skip directories larger than this
export KINDLING_MAX_DIR_FILES=20000   # Skip directories with more files

# Streaming settings
export KINDLING_BATCH_SIZE=5000       # Files per UI batch (default: 2000)
export KINDLING_WALK_QUEUE_SIZE=20000 # Backpressure queue (default: 10000)

# Progressive UI updates (experimental)
export KINDLING_PROGRESSIVE_UI=true   # Show results as they stream in

# Run with debug logging to monitor indexing
export KINDLING_DEBUG=1
bin/kindling
```

**Performance characteristics:**
- With `fd`: First results in ~200-400ms on 100k+ file repos
- Indexing speed: 10,000-50,000 files/second (with fd/rg)
- Memory usage: Bounded to a few hundred MB even on 500k+ files
- Cache: Speeds up re-opens of the same repository
- Cancellation: Interrupts in <100ms when switching folders

---

## 🛠 Development

### Project Structure
```
kindling/
├── bin/kindling          # Main executable
├── lib/
│   ├── kindling/
│   │   ├── app.rb        # Application bootstrap
│   │   ├── indexer.rb    # File indexing with ignore rules
│   │   ├── fuzzy.rb      # Fuzzy search implementation
│   │   ├── tree_renderer.rb  # ASCII tree generation
│   │   └── ui/           # GTK UI components
│   └── kindling.rb       # Main module
└── test/                 # Test suite
```

### Architecture
- **Non-blocking indexing**: Files are indexed in a background thread
- **Debounced search**: 200ms delay prevents UI lag while typing
- **Memory efficient**: Stays under 250MB even with 100k+ files
- **Pure Ruby fuzzy search**: No external dependencies for core logic

### Performance Targets
- Index 50k files: < 5 seconds
- Search response: < 50ms on M1
- Memory usage: < 250MB
- UI stays responsive during all operations

---

## 🗺 Roadmap

### Next Up (v0.2)
- [ ] Respect `.gitignore` patterns fully
- [ ] File content preview pane
- [ ] Keyboard shortcuts (Cmd+O, Cmd+C, etc.)
- [ ] Remember window size and position

### Future (v1.0)
- [ ] Checkable tree view for folder selection
- [ ] Save/load context bundles
- [ ] Advanced search syntax (`ext:rb`, `path:app/`)
- [ ] Export formats (Markdown, JSON)
- [ ] Plugin system for custom tree formats

---

## 🤝 Contributing

Pull requests welcome! If you'd like to propose new features or bugfixes, please open an issue first to discuss.

### Running Tests
```bash
# Run all tests
rake test

# Run only unit tests
rake unit

# Run with coverage report
rake coverage
```

### Code Style
We use both RuboCop and Standard for linting:
```bash
# Check for style issues
rake lint

# Auto-fix style issues
rake lint:fix
```

---

## 📜 License

Kindling is open source under the [MIT License](LICENSE).

---

## 🔥 Why "Kindling"?

When starting a fire, you don't throw on a giant log right away—you gather kindling to spark it.
In the same way, this tool helps you collect the small, essential pieces of context that let your work with AI catch fire.