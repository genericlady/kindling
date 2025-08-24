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
      # Cancel any existing indexing operation
      @indexer&.cancel!
      @index_generation += 1
      current_gen = @index_generation
      
      @indexer = Indexer.new
      @current_root = root_path
      
      # Show initial progress
      @window.show_progress_spinner
      @window.update_progress("Scanning #{File.basename(root_path)}...")
      
      # Run indexing in a worker thread
      @indexing_thread = Thread.new do
        begin
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
            }
          ) do |paths|
            # On completion, update UI on main thread
            GLib::Idle.add do
              if current_gen == @index_generation
                @paths = paths
                @window.update_file_list(@paths)
                @window.hide_progress_spinner
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
            @window.hide_progress_spinner
            @window.update_progress("Indexing failed: #{e.message}")
            Logging.error("Indexing failed: #{e.message}")
            false
          end
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