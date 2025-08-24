# frozen_string_literal: true

module Kindling
  module UI
    # Main application window with paned layout
    class Window < Gtk::ApplicationWindow
      def initialize(app)
        super(app)
        
        set_title("Kindling")
        set_default_size(Config::WINDOW_WIDTH, Config::WINDOW_HEIGHT)
        set_position(:center)
        
        @callbacks = {}
        
        setup_ui
        setup_signals
      end
      
      # Event callbacks
      def on_folder_chosen(&block)
        @callbacks[:folder_chosen] = block
      end
      
      def on_search_changed(&block)
        @callbacks[:search_changed] = block
      end
      
      def on_selection_changed(&block)
        @callbacks[:selection_changed] = block
      end
      
      def on_copy_requested(&block)
        @callbacks[:copy_requested] = block
      end
      
      # UI updates
      def update_progress(message)
        @header.update_progress(message)
      end
      
      def show_progress_spinner
        @header.show_progress_spinner
      end
      
      def hide_progress_spinner
        @header.hide_progress_spinner
      end
      
      def update_file_list(paths)
        @file_list.update(paths)
      end
      
      def clear_file_selections
        @file_list.clear_selection
      end
      
      def update_preview(content)
        @preview.update(content)
      end
      
      def enable_copy_button
        @header.enable_copy_button
      end
      
      def disable_copy_button
        @header.disable_copy_button
      end
      
      def flash_success(message)
        original_title = title
        set_title("#{title} - #{message}")
        GLib::Timeout.add(1000) do
          set_title(original_title)
          false # Don't repeat
        end
      end
      
      private
      
      def setup_ui
        # Main vertical box
        vbox = Gtk::Box.new(:vertical, 0)
        add(vbox)
        
        # Header with controls
        @header = Header.new
        vbox.pack_start(@header, expand: false, fill: true, padding: 0)
        
        # Horizontal paned container for file list and preview
        paned = Gtk::Paned.new(:horizontal)
        paned.position = (Config::WINDOW_WIDTH * Config::PANE_POSITION).to_i
        vbox.pack_start(paned, expand: true, fill: true, padding: 0)
        
        # Left: File list
        @file_list = FileList.new
        paned.pack1(@file_list, resize: true, shrink: false)
        
        # Right: Preview
        @preview = Preview.new
        paned.pack2(@preview, resize: true, shrink: false)
      end
      
      def setup_signals
        # Wire header signals
        @header.on_folder_chosen do |path|
          @callbacks[:folder_chosen]&.call(path)
        end
        
        @header.on_search_changed do |query|
          @callbacks[:search_changed]&.call(query)
        end
        
        @header.on_copy_clicked do
          @callbacks[:copy_requested]&.call
        end
        
        # Wire file list selection changes
        @file_list.on_selection_changed do |paths|
          @callbacks[:selection_changed]&.call(paths)
        end
        
        # Handle window close
        signal_connect("destroy") do
          Gtk.main_quit
        end
      end
    end
  end
end