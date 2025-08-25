# frozen_string_literal: true

module Kindling
  module UI
    # File list with multi-select support
    class FileList < Gtk::ScrolledWindow
      def initialize
        super

        @callbacks = {}
        @store = nil
        @tree_view = nil
        @loader = nil
        @loader_box = nil
        @empty_state = nil
        @overlay = nil

        set_policy(:automatic, :automatic)
        set_hexpand(true)
        set_vexpand(true)

        setup_ui
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

        # Clear the store but NOT the selection set
        # We want to preserve ALL selections, not just visible ones
        @store.clear

        # Batch add paths (cap for UI performance)
        display_paths = paths.first(Config::MAX_VISIBLE_RESULTS)

        display_paths.each do |path|
          iter = @store.append
          # Check if this path is in our persistent selection set
          is_selected = @selected_set.include?(path)
          iter[0] = is_selected  # Checkbox state
          iter[1] = path         # File path
        end

        # Reattach model
        @tree_view.model = @store

        # Update status if truncated
        if paths.size > display_paths.size
          Logging.debug("Showing #{display_paths.size} of #{paths.size} results")
        end

        # No need to notify about selection changes - selections are preserved
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

      # Show loading loader
      def show_loading
        # Add loader to overlay if not already added
        if !@loader_added && @loader_box
          @overlay.add_overlay(@loader_box)
          @loader_added = true
        end

        @empty_state&.hide  # Hide empty state
        @tree_view&.hide    # Hide tree view
        @loader&.start     # Start loader animation
        @loader_box&.show  # Show loader box
      end

      # Hide loading loader
      def hide_loading
        @loader&.stop      # Stop loader animation
        @loader_box&.hide  # Hide loader box
        @empty_state&.hide  # Hide empty state (in case it's still showing)
        @tree_view&.show    # Show tree view with results
      end

      # Show empty state (when no folder is open)
      def show_empty_state
        @loader&.stop
        @loader_box&.hide
        @tree_view&.hide
        @empty_state&.show
      end

      private

      def setup_ui
        # Create overlay to hold tree view, loader, and empty state
        @overlay = Gtk::Overlay.new
        add(@overlay)

        # Setup tree view
        setup_tree_view
        @overlay.add(@tree_view)
        @tree_view.hide # Hidden initially

        # Setup loader (centered)
        setup_loader

        # Setup empty state (shown by default)
        setup_empty_state
      end

      def setup_empty_state
        # Create a box for the empty state
        @empty_state = Gtk::Box.new(:vertical, 20)
        @empty_state.set_valign(:center)
        @empty_state.set_halign(:center)

        # Add an icon (folder icon)
        icon = Gtk::Image.new(icon_name: "folder-open", size: :dialog)
        icon.pixel_size = 64
        icon.style_context.add_class("dim-label")
        @empty_state.pack_start(icon, expand: false, fill: false, padding: 0)

        # Add main message
        title = Gtk::Label.new
        title.markup = "<big><b>No folder open</b></big>"
        title.style_context.add_class("dim-label")
        @empty_state.pack_start(title, expand: false, fill: false, padding: 0)

        @overlay.add_overlay(@empty_state)
        @empty_state.show # Shown by default
      end

      def setup_loader
        # Create a box to center the loader
        @loader_box = Gtk::Box.new(:vertical, 10)
        @loader_box.set_valign(:center)
        @loader_box.set_halign(:center)

        @loader = Gtk::Spinner.new
        @loader.set_size_request(32, 32)
        @loader_box.pack_start(@loader, expand: false, fill: false, padding: 0)

        # Add a label below the loader
        label = Gtk::Label.new("Loading files...")
        label.style_context.add_class("dim-label")
        @loader_box.pack_start(label, expand: false, fill: false, padding: 0)

        # Don't add to overlay here - will be added when needed
        @loader_added = false
      end

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

        # Don't add to scrolled window here - it's added to overlay in setup_ui
      end
    end
  end
end
