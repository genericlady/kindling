# frozen_string_literal: true

module Kindling
  module UI
    # Preview pane showing ASCII tree
    class Preview < Gtk::ScrolledWindow
      def initialize
        super

        set_policy(:automatic, :automatic)
        set_hexpand(true)
        set_vexpand(true)

        setup_text_view
      end

      # Update preview content
      def update(content)
        @buffer.text = content || ""
      end

      # Clear preview
      def clear
        @buffer.text = ""
      end

      private

      def setup_text_view
        # Create text view with buffer
        @text_view = Gtk::TextView.new
        @text_view.editable = false
        @text_view.cursor_visible = false
        @text_view.wrap_mode = :none

        # Set monospace font for proper tree rendering
        @text_view.override_font(Pango::FontDescription.new("Monospace 11"))

        # Add some padding
        @text_view.left_margin = 10
        @text_view.right_margin = 10
        @text_view.top_margin = 10
        @text_view.bottom_margin = 10

        @buffer = @text_view.buffer

        # Add placeholder text
        @buffer.text = "Select files to preview tree structure"

        add(@text_view)
      end
    end
  end
end
