# Kindling 🔥

**Kindling** is a lightweight desktop tool written in **Ruby + GTK3** that helps you gather and shape context when working with AI.  

Instead of manually hunting for files and pasting snippets, Kindling lets you:  
- Open a project folder  
- Fuzzy-search across its files  
- Select only what matters  
- Copy a clean, ASCII-style file tree to your clipboard  

Perfect for building prompts where you need to “prime” the AI with project structure.

---

## ✨ Features (MVP)

- **Open a project folder** – start from your codebase or docs.  
- **Fuzzy file search** – type a few characters to quickly find files.  
- **Multi-select** – pick multiple files at once.  
- **Tree preview** – see the hierarchy of your selected files as an ASCII tree.  
- **One-click copy** – instantly copy that tree to your clipboard, ready to drop into a prompt or chat.  

Example output:

my-project/
├── Gemfile
├── app/
│   ├── models/
│   │   └── user.rb
│   └── views/
│       └── index.html.erb
└── spec/
└── user_spec.rb

---

## 🚀 Getting Started

### Prerequisites

- Ruby **3.2+** (works with 3.3 as well)  
- Bundler  
- GTK3 dev libraries (`brew install gtk+3` on macOS, `apt install libgtk-3-dev` on Debian/Ubuntu)

### Install

```bash
git clone https://github.com/yourusername/kindling.git
cd kindling
bundle install

Run

bundle exec ruby context-builder.rb


⸻

🗺 Roadmap
	•	Respect .gitignore when indexing
	•	Checkable tree view for selecting folders as well as files
	•	File content preview
	•	Save context bundles for reuse
	•	Advanced search filters (e.g. ext:rb, path:app/)
	•	Export snippets (Markdown, plain text, JSON)

⸻

🤝 Contributing

Pull requests welcome! If you’d like to propose new features or bugfixes, please open an issue first to discuss.

⸻

📜 License

MIT License. See LICENSE for details.

⸻

🔥 Why “Kindling”?

When starting a fire, you don’t throw on a giant log right away—you gather kindling to spark it.
In the same way, this tool helps you collect the small, essential pieces of context that let your work with AI catch fire.
