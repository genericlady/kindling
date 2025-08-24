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
      
      @window.show_all
      Logging.debug("Window activated and shown")
    end
    
    def index_folder(root_path)
      # TODO: Cancel any existing indexing operation
      @index_generation += 1
      current_gen = @index_generation
      
      @indexer = Indexer.new
      
      # Run indexing in a worker thread
      Thread.new do
        begin
          @indexer.index(root_path, 
            on_progress: ->(count) { 
              GLib::Idle.add { 
                @window.update_progress("Indexing #{count} files...") if current_gen == @index_generation
                false # Don't repeat
              }
            }
          ) do |paths|
            # On completion, update UI on main thread
            GLib::Idle.add do
              if current_gen == @index_generation
                @paths = paths
                @window.update_file_list(@paths)
                @window.update_progress("#{@paths.size} files indexed")
                Logging.debug("Indexed #{@paths.size} files from #{root_path}")
              end
              false
            end
          end
        rescue => e
          Logging.error("Indexing failed: #{e.message}")
        end
      end
    end
    
    def filter_files(query)
      # TODO: Implement debounced search
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
      
      tree = TreeRenderer.render(@selected_paths.to_a)
      if Clipboard.copy(tree)
        @window.flash_success("✓ Copied")
        Logging.debug("Copied #{@selected_paths.size} paths to clipboard")
      else
        Logging.error("Failed to copy to clipboard")
      end
    end
  end
end