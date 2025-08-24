# Kindling 🔥

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
- **Smart ignoring** – automatically skips `.git`, `node_modules`, `.DS_Store` and other noise

### Example output:
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

---

## 🚀 Getting Started

### Prerequisites

- Ruby **3.2+** (tested with 3.3.5)  
- Bundler  
- GTK3 dev libraries:
  - **macOS**: `brew install gtk+3`
  - **Ubuntu/Debian**: `apt install libgtk-3-dev`
  - **Fedora**: `dnf install gtk3-devel`

### Install

```bash
git clone https://github.com/yourusername/kindling.git
cd kindling
bundle install
```

### Run

```bash
# Run the app
bin/kindling

# Or with debug logging
KINDLING_DEBUG=1 bin/kindling

# Run tests
rake test

# Run benchmarks
rake bench

```

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
rake lint
```

---

## 📜 License

Kindling is open source under the [MIT License](LICENSE).

---

## 🔥 Why "Kindling"?

When starting a fire, you don't throw on a giant log right away—you gather kindling to spark it.
In the same way, this tool helps you collect the small, essential pieces of context that let your work with AI catch fire.