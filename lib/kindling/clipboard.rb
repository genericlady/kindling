# frozen_string_literal: true

module Kindling
  # Cross-platform clipboard helper using GTK
  module Clipboard
    extend self

    # Copy text to system clipboard
    # @param text [String] Text to copy
    # @return [Boolean] Success status
    def copy(text)
      return false if text.nil? || text.empty?

      begin
        display = Gdk::Display.default
        clipboard = Gtk::Clipboard.get_default(display)
        clipboard.text = text
        clipboard.store if clipboard.respond_to?(:store)

        Logging.debug("Copied #{text.lines.count} lines to clipboard")
        true
      rescue => e
        Logging.error("Clipboard copy failed: #{e.message}")
        false
      end
    end

    # Get text from clipboard (for testing/debugging)
    # @return [String, nil] Clipboard contents
    def paste
      display = Gdk::Display.default
      clipboard = Gtk::Clipboard.get_default(display)
      clipboard.wait_for_text
    rescue => e
      Logging.error("Clipboard paste failed: #{e.message}")
      nil
    end

    # Clear clipboard
    def clear
      display = Gdk::Display.default
      clipboard = Gtk::Clipboard.get_default(display)
      clipboard.clear
      true
    rescue => e
      Logging.error("Clipboard clear failed: #{e.message}")
      false
    end
  end
end
