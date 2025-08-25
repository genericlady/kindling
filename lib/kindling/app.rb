# frozen_string_literal: true

module Kindling
  # Main application bootstrapper - handles GTK initialization and window creation
  class App
    def self.run(argv = [])
      new.run(argv)
    end

    def initialize
      @app = Gtk::Application.new("com.kindling.app", :flags_none)
      @window = nil
      @paths = []
      @selected_paths = Selection.new
      @indexer = nil
      @index_generation = 0
      @include_contents = false
      @current_root = nil
      @loading_timer_id = nil
    end

    def run(argv)
      @app.signal_connect("startup") { on_startup }
      @app.signal_connect("activate") { on_activate }
      @app.run(argv)
    end

    private

    def on_startup
      # TODO: Set up global accelerators (Cmd+O, Cmd+C, etc.)
      Logging.debug("Application starting up")
    end

    def on_activate
      @window = UI::Window.new(@app)

      # Wire up signals
      @window.on_folder_chosen { |path| index_folder(path) }
      @window.on_search_changed { |query| filter_files(query) }
      @window.on_selection_changed { |paths| update_selection(paths) }
      @window.on_copy_requested { copy_tree_to_clipboard }
      @window.on_include_contents_changed { |checked| @include_contents = checked }

      @window.show_all
      Logging.debug("Window activated and shown")
    end

    def index_folder(root_path)
      # Cancel any existing indexing operation
      @indexer&.cancel!
      cancel_loading_timer!
      @index_generation += 1
      current_gen = @index_generation

      @indexer = Indexer.new
      @current_root = root_path

      # Clear previous selections when opening a new folder
      @window.clear_file_selections
      @selected_paths.clear

      # Delay showing loaders to avoid flashing for fast scans
      @loading_timer_id = GLib::Timeout.add(250) do
        if current_gen == @index_generation
          @window.show_file_list_loading
          @window.show_progress_loader
          @window.update_progress("Scanning #{File.basename(root_path)}...")
        end
        @loading_timer_id = nil
        false # don't repeat
      end

      # Run indexing in a worker thread
      @indexing_thread = Thread.new do
        start_time = Time.now
        last_update = Time.now

        @indexer.index(root_path,
          on_progress: ->(count) {
            # Throttle updates to every 100ms
            now = Time.now
            if now - last_update > 0.1
              GLib::Idle.add {
                if current_gen == @index_generation
                  elapsed = (now - start_time).round(1)
                  @window.update_progress("Indexing... #{count} files (#{elapsed}s)")
                end
                false # Don't repeat
              }
              last_update = now
            end
          }) do |paths|
          # On completion, update UI on main thread
          GLib::Idle.add do
            if current_gen == @index_generation
              @paths = paths
              cancel_loading_timer!
              @window.hide_file_list_loading
              @window.update_file_list(@paths)
              @window.hide_progress_loader
              elapsed = (Time.now - start_time).round(1)
              @window.update_progress("#{@paths.size} files • #{File.basename(root_path)} • #{elapsed}s")
              Logging.debug("Indexed #{@paths.size} files from #{root_path} in #{elapsed}s")

              # Log memory usage if in debug mode
              Config.log_memory("after indexing") if ENV["KINDLING_DEBUG"]
            end
            false
          end
        end
      rescue => e
        GLib::Idle.add do
          cancel_loading_timer!
          @window.hide_file_list_loading
          @window.hide_progress_loader
          @window.update_progress("Indexing failed: #{e.message}")
          Logging.error("Indexing failed: #{e.message}")
          false
        end
      end
    end

    def filter_files(query)
      # Debouncing is handled by the header component
      filtered = if query.nil? || query.empty?
        @paths.first(10_000) # Cap for UI performance
      else
        Fuzzy.filter(@paths, query, limit: 5_000)
      end

      @window.update_file_list(filtered)
      Logging.debug("Filtered to #{filtered.size} results for query: #{query}")
    end

    def update_selection(paths)
      @selected_paths.replace(paths)

      # Update preview
      if @selected_paths.any?
        tree = TreeRenderer.render(@selected_paths.to_a)
        @window.update_preview(tree)
        @window.enable_copy_button
      else
        @window.update_preview("")
        @window.disable_copy_button
      end
    end

    def copy_tree_to_clipboard
      return if @selected_paths.empty?

      # Generate the tree
      tree = TreeRenderer.render(@selected_paths.to_a)

      # Build the output (ensure UTF-8 encoding)
      output = tree.dup.force_encoding("UTF-8")

      # Add file contents if requested
      if @include_contents && @current_root
        file_contents = format_file_contents(@selected_paths.to_a)
        separator = String.new("\n\n", encoding: "UTF-8")
        output = output + separator + file_contents
      end

      if Clipboard.copy(output)
        message = @include_contents ? "✓ Copied with contents" : "✓ Copied"
        @window.flash_success(message)
        Logging.debug("Copied #{@selected_paths.size} paths to clipboard#{@include_contents ? " with contents" : ""}")
      else
        Logging.error("Failed to copy to clipboard")
      end
    end

    def format_file_contents(relative_paths)
      contents = []

      relative_paths.each do |relative_path|
        full_path = File.join(@current_root, relative_path)

        # Skip directories and unreadable files
        next unless File.file?(full_path) && File.readable?(full_path)

        begin
          # Read file content with UTF-8 encoding (limit size for safety)
          content = File.read(full_path, 1_000_000, encoding: "UTF-8", invalid: :replace, undef: :replace)

          # Detect language for syntax highlighting
          language = detect_language(relative_path)

          # Add formatted content block
          contents << "## #{relative_path}\n\n```#{language}\n#{content}\n```"
        rescue => e
          Logging.debug("Could not read file #{relative_path}: #{e.message}")
          contents << "## #{relative_path}\n\n```\n[Error reading file: #{e.message}]\n```"
        end
      end

      contents.join("\n\n").force_encoding("UTF-8")
    end

    def detect_language(filepath)
      # Extract extension
      ext = File.extname(filepath).downcase

      # Map common extensions to languages
      case ext
      when ".rb", ".rake" then "ruby"
      when ".js", ".jsx" then "javascript"
      when ".ts", ".tsx" then "typescript"
      when ".py" then "python"
      when ".java" then "java"
      when ".c" then "c"
      when ".cpp", ".cc", ".cxx" then "cpp"
      when ".cs" then "csharp"
      when ".go" then "go"
      when ".rs" then "rust"
      when ".php" then "php"
      when ".swift" then "swift"
      when ".kt", ".kts" then "kotlin"
      when ".scala" then "scala"
      when ".r" then "r"
      when ".sh", ".bash" then "bash"
      when ".zsh" then "zsh"
      when ".fish" then "fish"
      when ".ps1" then "powershell"
      when ".html", ".htm" then "html"
      when ".xml" then "xml"
      when ".css" then "css"
      when ".scss", ".sass" then "scss"
      when ".less" then "less"
      when ".json" then "json"
      when ".yaml", ".yml" then "yaml"
      when ".toml" then "toml"
      when ".ini" then "ini"
      when ".sql" then "sql"
      when ".md", ".markdown" then "markdown"
      when ".tex" then "latex"
      when ".vim" then "vim"
      when ".lua" then "lua"
      when ".pl" then "perl"
      when ".ex", ".exs" then "elixir"
      when ".clj", ".cljs" then "clojure"
      when ".elm" then "elm"
      when ".hs" then "haskell"
      when ".ml", ".mli" then "ocaml"
      when ".fs", ".fsx" then "fsharp"
      when ".vue" then "vue"
      when ".svelte" then "svelte"
      else
        # Check for special filenames
        case File.basename(filepath).downcase
        when "makefile", "gnumakefile" then "makefile"
        when "dockerfile" then "dockerfile"
        when "gemfile", "rakefile" then "ruby"
        when "package.json", "tsconfig.json" then "json"
        when ".gitignore", ".dockerignore" then "gitignore"
        else
          "" # No language hint
        end
      end
    end

    def cancel_loading_timer!
      if @loading_timer_id
        GLib::Source.remove(@loading_timer_id)
        @loading_timer_id = nil
      end
    end
  end
end
