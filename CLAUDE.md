# TESTING
- Code Coverage should always be >= 85%
- to run tests
```
rake test
```

# DOCUMENTATION
- Keep README.md in project root up to date

# MVP

here’s a crisp, senior-level build plan for **Kindling** (Ruby + GTK3). it’s scoped for an MVP with a clean path to a 1.0.

# Kindling — Engineering Plan

### 0) Goals & non-goals

**Goals (MVP)**
* Open a project folder
* Fuzzy search files
* Multi-select files
* Copy an ASCII file-tree of the selection to clipboard
* Solid tests (Minitest), clean packaging on macOS & Linux

⠀
**Non-goals (MVP)**
* Content preview, snippets export formats, .gitignore parity with git itself (basic ignore only)
* Windows packaging
* LSP integration or AI API calls

⠀
⸻

### 1) Architecture & components

**App type:** single-process GTK3 desktop app with a small domain core.

**Modules**
* Kindling::App — GTK app bootstrapping (window, signals)
* Kindling::Indexer — recursive, cancellable file indexer with ignore rules
* Kindling::Fuzzy — scorer + filter (pure Ruby; fast enough for ≤100k paths)
* Kindling::Selection — tracks selected relative paths
* Kindling::TreeRenderer — builds nested map, renders ASCII tree
* Kindling::Clipboard — cross-platform clipboard helper (GTK Gdk::Display)
* Kindling::Config — ignores, perf knobs (max files, skip large dirs)
* Kindling::Logging — structured logs (stdout, debug toggle)
* UI::* — GTK widgets: header, file list, preview pane

⠀
**Threading model**
* Main thread: UI
* Worker thread: indexing (GLib::Idle.add / GLib::Timeout to marshal updates)
* Debounced search (200ms) on main thread using in-memory index

⠀
**Data flow**
1. User chooses folder → Indexer#index(root) builds @paths
2. Search query → Fuzzy.filter(@paths, q) returns ordered subset
3. Selection in list → TreeRenderer.render(selected) updates preview
4. Copy → Clipboard.copy(rendered_tree)

⠀
⸻

### 2) Tech stack
* Ruby 3.2+ (target 3.3)
* Gems: gtk3, gio2, gobject-introspection
* Dev tooling: rubocop, standardrb (pick one), rake, minitest, simplecov
* Packaging: ruby-packer (Traveling Ruby alternative) or brew formula later; for Linux, AppImage via ruby-appimage (post-MVP)

⠀
⸻

### 3) Project layout

kindling/
├─ bin/
│  └─ kindling             # executable (#!/usr/bin/env ruby)
├─ lib/
│  ├─ kindling.rb
│  ├─ kindling/app.rb
│  ├─ kindling/indexer.rb
│  ├─ kindling/fuzzy.rb
│  ├─ kindling/selection.rb
│  ├─ kindling/tree_renderer.rb
│  ├─ kindling/clipboard.rb
│  ├─ kindling/config.rb
│  ├─ kindling/logging.rb
│  └─ kindling/ui/
│     ├─ window.rb
│     ├─ header.rb
│     ├─ file_list.rb
│     └─ preview.rb
├─ test/
│  ├─ test_helper.rb
│  ├─ unit/
│  │  ├─ indexer_test.rb
│  │  ├─ fuzzy_test.rb
│  │  └─ tree_renderer_test.rb
│  └─ integration/
│     └─ app_smoke_test.rb
├─ assets/                  # icons/screenshots later
├─ README.md
├─ LICENSE
├─ Gemfile
└─ Rakefile

Key design details

### Indexer
* Use Find.find with Find.prune on ignore dirs
* Optional file size cap (e.g., skip files > 5 MB for future content preview)
* Emit periodic “heartbeat” to UI with count (every 250ms)
* Provide cancel! flag checked each N iterations to abort quickly

⠀
### Fuzzy matching
* Subsequence score with bonuses: consecutive hits, start-of-segment (/, _, -)
* Precompute lowercase path and basename; prefer basename matches
* Return top N (cap to 5k in list to avoid GTK churn)

⠀
### Tree rendering
* Build nested hash { "dir" => { "file" => true } }
* Stable sorting; render ├──/└── box-drawing chars; include root folder display name
* Unit tests cover deep nesting, shared prefixes, ordering, unicode filenames

⠀
### GTK performance
* Use Gtk::ListStore with TreeView; batch inserts (freeze/thaw)
* Avoid per-row widget creation; text renderer only
* Debounce search updates; keep UI responsive

⠀
### Clipboard
* Gdk::Display.default + Gtk::Clipboard.get with Gdk::SELECTION_CLIPBOARD
* Title “toast” tick (✓ Copied) via temporary window title change

⠀
### Config & logging
* Kindling::Config defaults; XDG_CONFIG_HOME path
* ENV["KINDLING_DEBUG"] toggles verbose logs; Logging.debug/info/warn
