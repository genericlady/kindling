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
        
        # Clear store but preserve selections for paths that still exist
        old_selections = @selected_set.dup
        @store.clear
        @selected_set.clear
        
        # Batch add paths (cap for UI performance)
        display_paths = paths.first(Config::MAX_VISIBLE_RESULTS)
        
        display_paths.each do |path|
          iter = @store.append
          # Check if this path was previously selected
          was_selected = old_selections.include?(path)
          iter[0] = was_selected  # Checkbox state
          iter[1] = path          # File path
          
          # Restore selection state
          if was_selected
            @selected_set.add(path)
          end
        end
        
        # Reattach model
        @tree_view.model = @store
        
        # Update status if truncated
        if paths.size > display_paths.size
          Logging.debug("Showing #{display_paths.size} of #{paths.size} results")
        end
        
        # Notify if selections changed due to filtering
        if @selected_set != old_selections
          @callbacks[:selection_changed]&.call(@selected_set.to_a.sort)
        end
      end
      
      # Get selected paths
      def selected_paths
        @selected_set.to_a.sort
      end
      
      # Select all visible items
      def select_all
        @store.each do |_model, _path, iter|
          iter[0] = true
          @selected_set.add(iter[1])
        end
        @callbacks[:selection_changed]&.call(@selected_set.to_a.sort)
      end
      
      # Clear all selections
      def clear_selection
        @store.each do |_model, _path, iter|
          iter[0] = false
        end
        @selected_set.clear
        @callbacks[:selection_changed]&.call([])
      end
      
      private
      
      def setup_tree_view
        # Create list store with checkbox state (Boolean) and path (String)
        @store = Gtk::ListStore.new(TrueClass, String)
        @selected_set = Set.new
        
        # Create tree view
        @tree_view = Gtk::TreeView.new(@store)
        @tree_view.headers_visible = false
        
        # Disable GTK selection - we'll use checkboxes instead
        @tree_view.selection.mode = :none
        
        # Add checkbox column
        checkbox_renderer = Gtk::CellRendererToggle.new
        checkbox_renderer.signal_connect("toggled") do |_renderer, path|
          iter = @store.get_iter(path)
          if iter
            # Toggle the checkbox
            iter[0] = !iter[0]
            
            # Update our selection tracking
            file_path = iter[1]
            if iter[0]
              @selected_set.add(file_path)
            else
              @selected_set.delete(file_path)
            end
            
            # Notify listeners
            @callbacks[:selection_changed]&.call(@selected_set.to_a.sort)
          end
        end
        
        checkbox_column = Gtk::TreeViewColumn.new("", checkbox_renderer, active: 0)
        @tree_view.append_column(checkbox_column)
        
        # Add file path column
        text_renderer = Gtk::CellRendererText.new
        text_renderer.ellipsize = :middle # Handle long paths
        
        path_column = Gtk::TreeViewColumn.new("Path", text_renderer, text: 1)
        @tree_view.append_column(path_column)
        
        # Add to scrolled window
        add(@tree_view)
      end
    end
  end
end