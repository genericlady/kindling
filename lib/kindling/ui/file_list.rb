# frozen_string_literal: true

module Kindling
  module UI
    # File list with multi-select support
    class FileList < Gtk::ScrolledWindow
      def initialize
        super()
        
        @callbacks = {}
        @store = nil
        @tree_view = nil
        
        set_policy(:automatic, :automatic)
        set_hexpand(true)
        set_vexpand(true)
        
        setup_tree_view
      end
      
      # Event callbacks
      def on_selection_changed(&block)
        @callbacks[:selection_changed] = block
      end
      
      # Update the file list with new paths
      def update(paths)
        return unless @store
        
        # Detach model for performance
        @tree_view.model = nil
        
        # Clear and refill
        @store.clear
        
        # Batch add paths (cap for UI performance)
        display_paths = paths.first(Config::MAX_VISIBLE_RESULTS)
        
        display_paths.each do |path|
          iter = @store.append
          iter[0] = path
        end
        
        # Reattach model
        @tree_view.model = @store
        
        # Update status if truncated
        if paths.size > display_paths.size
          Logging.debug("Showing #{display_paths.size} of #{paths.size} results")
        end
      end
      
      # Get selected paths
      def selected_paths
        paths = []
        selection = @tree_view.selection
        
        selection.each do |_model, _path, iter|
          paths << iter[0]
        end
        
        paths
      end
      
      private
      
      def setup_tree_view
        # Create list store with single string column
        @store = Gtk::ListStore.new(String)
        
        # Create tree view
        @tree_view = Gtk::TreeView.new(@store)
        @tree_view.headers_visible = false
        
        # Enable multi-select
        @tree_view.selection.mode = :multiple
        
        # Add single column for file path
        renderer = Gtk::CellRendererText.new
        renderer.ellipsize = :middle # Handle long paths
        
        column = Gtk::TreeViewColumn.new("Path", renderer, text: 0)
        @tree_view.append_column(column)
        
        # Handle selection changes
        @tree_view.selection.signal_connect("changed") do
          @callbacks[:selection_changed]&.call(selected_paths)
        end
        
        # Add to scrolled window
        add(@tree_view)
      end
    end
  end
end