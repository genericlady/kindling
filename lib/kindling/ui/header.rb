# frozen_string_literal: true

module Kindling
  module UI
    # Header bar with folder chooser, search, and copy button
    class Header < Gtk::Box
      def initialize
        super(:horizontal, 5)
        
        @callbacks = {}
        @debounce_timer = nil
        
        set_margin_top(5)
        set_margin_bottom(5)
        set_margin_start(10)
        set_margin_end(10)
        
        setup_widgets
      end
      
      # Event callbacks
      def on_folder_chosen(&block)
        @callbacks[:folder_chosen] = block
      end
      
      def on_search_changed(&block)
        @callbacks[:search_changed] = block
      end
      
      def on_copy_clicked(&block)
        @callbacks[:copy_clicked] = block
      end
      
      # UI updates
      def update_progress(message)
        @folder_button.label = message
      end
      
      def enable_copy_button
        @copy_button.sensitive = true
      end
      
      def disable_copy_button
        @copy_button.sensitive = false
      end
      
      private
      
      def setup_widgets
        # Open Folder button
        @folder_button = Gtk::Button.new(label: "Open Folder")
        @folder_button.signal_connect("clicked") { choose_folder }
        pack_start(@folder_button, expand: false, fill: false, padding: 0)
        
        # Search entry (takes most space)
        @search_entry = Gtk::SearchEntry.new
        @search_entry.placeholder_text = "Search files..."
        @search_entry.signal_connect("search-changed") { on_search_changed_internal }
        pack_start(@search_entry, expand: true, fill: true, padding: 0)
        
        # Copy button
        @copy_button = Gtk::Button.new(label: "Copy Selected Tree")
        @copy_button.sensitive = false
        @copy_button.signal_connect("clicked") { @callbacks[:copy_clicked]&.call }
        pack_start(@copy_button, expand: false, fill: false, padding: 0)
      end
      
      def choose_folder
        dialog = Gtk::FileChooserDialog.new(
          title: "Choose Project Folder",
          parent: toplevel,
          action: :select_folder,
          buttons: [
            [Gtk::Stock::CANCEL, :cancel],
            [Gtk::Stock::OPEN, :accept]
          ]
        )
        
        if dialog.run == :accept
          folder = dialog.filename
          @callbacks[:folder_chosen]&.call(folder)
          
          # Update button to show folder name
          @folder_button.label = File.basename(folder)
        end
        
        dialog.destroy
      end
      
      def on_search_changed_internal
        # Cancel existing timer
        if @debounce_timer
          GLib::Source.remove(@debounce_timer)
        end
        
        # Start new timer
        @debounce_timer = GLib::Timeout.add(Config::DEBOUNCE_MS) do
          @callbacks[:search_changed]&.call(@search_entry.text)
          @debounce_timer = nil
          false # Don't repeat
        end
      end
    end
  end
end