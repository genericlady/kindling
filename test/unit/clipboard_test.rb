# frozen_string_literal: true

require_relative "../test_helper"

class ClipboardTest < Minitest::Test
  def setup
    @mock_clipboard = Minitest::Mock.new
    @mock_display = Minitest::Mock.new
  end

  def test_copy_returns_false_for_nil_text
    result = Kindling::Clipboard.copy(nil)
    refute result
  end

  def test_copy_returns_false_for_empty_text
    result = Kindling::Clipboard.copy("")
    refute result
  end

  def test_copy_success
    text = "Sample text to copy"

    # Create a simple mock clipboard that responds to needed methods
    mock_clipboard = Object.new
    def mock_clipboard.text=(val)
      @text = val
    end

    def mock_clipboard.respond_to?(method)
      method == :store
    end

    def mock_clipboard.store
    end

    # Stub the GTK calls
    Gdk::Display.stub :default, @mock_display do
      Gtk::Clipboard.stub :get_default, mock_clipboard do
        # Capture debug log
        logged = false
        Kindling::Logging.stub :debug, proc { |msg| logged = true if msg.include?("1 lines") } do
          result = Kindling::Clipboard.copy(text)
          assert result
          assert logged
        end
      end
    end
  end

  def test_copy_multiline_text
    text = "Line 1\nLine 2\nLine 3"

    # Create a simple mock clipboard
    mock_clipboard = Object.new
    def mock_clipboard.text=(val)
      @text = val
    end

    def mock_clipboard.respond_to?(method)
      method == :store
    end

    def mock_clipboard.store
    end

    Gdk::Display.stub :default, @mock_display do
      Gtk::Clipboard.stub :get_default, mock_clipboard do
        # Check that it logs correct line count
        logged = false
        Kindling::Logging.stub :debug, proc { |msg| logged = true if msg.include?("3 lines") } do
          result = Kindling::Clipboard.copy(text)
          assert result
          assert logged
        end
      end
    end
  end

  def test_copy_without_store_method
    text = "Sample text"

    # Create a mock clipboard without store method
    mock_clipboard = Object.new
    def mock_clipboard.text=(val)
      @text = val
    end

    def mock_clipboard.respond_to?(method)
      false
    end

    Gdk::Display.stub :default, @mock_display do
      Gtk::Clipboard.stub :get_default, mock_clipboard do
        result = Kindling::Clipboard.copy(text)
        assert result
      end
    end
  end

  def test_copy_handles_exception
    text = "Sample text"
    error_logged = false

    # Make clipboard raise an error
    Gdk::Display.stub :default, proc { raise "GTK error" } do
      Kindling::Logging.stub :error, proc { |msg| error_logged = true if msg.include?("Clipboard copy failed") } do
        result = Kindling::Clipboard.copy(text)
        refute result
        assert error_logged
      end
    end
  end

  def test_paste_success
    expected_text = "Pasted text"

    @mock_clipboard.expect(:wait_for_text, expected_text)

    Gdk::Display.stub :default, @mock_display do
      Gtk::Clipboard.stub :get_default, @mock_clipboard, [@mock_display] do
        result = Kindling::Clipboard.paste
        assert_equal expected_text, result
      end
    end

    @mock_clipboard.verify
  end

  def test_paste_returns_nil_on_empty_clipboard
    @mock_clipboard.expect(:wait_for_text, nil)

    Gdk::Display.stub :default, @mock_display do
      Gtk::Clipboard.stub :get_default, @mock_clipboard, [@mock_display] do
        result = Kindling::Clipboard.paste
        assert_nil result
      end
    end

    @mock_clipboard.verify
  end

  def test_paste_handles_exception
    error_logged = false

    Gdk::Display.stub :default, proc { raise "GTK error" } do
      Kindling::Logging.stub :error, proc { |msg| error_logged = true if msg.include?("Clipboard paste failed") } do
        result = Kindling::Clipboard.paste
        assert_nil result
        assert error_logged
      end
    end
  end

  def test_clear_success
    @mock_clipboard.expect(:clear, nil)

    Gdk::Display.stub :default, @mock_display do
      Gtk::Clipboard.stub :get_default, @mock_clipboard, [@mock_display] do
        result = Kindling::Clipboard.clear
        assert result
      end
    end

    @mock_clipboard.verify
  end

  def test_clear_handles_exception
    error_logged = false

    Gdk::Display.stub :default, proc { raise "GTK error" } do
      Kindling::Logging.stub :error, proc { |msg| error_logged = true if msg.include?("Clipboard clear failed") } do
        result = Kindling::Clipboard.clear
        refute result
        assert error_logged
      end
    end
  end

  def test_copy_with_unicode_text
    unicode_text = "Hello 世界 🌍"

    # Create a simple mock clipboard
    mock_clipboard = Object.new
    def mock_clipboard.text=(val)
      @text = val
    end

    def mock_clipboard.respond_to?(method)
      method == :store
    end

    def mock_clipboard.store
    end

    Gdk::Display.stub :default, @mock_display do
      Gtk::Clipboard.stub :get_default, mock_clipboard do
        result = Kindling::Clipboard.copy(unicode_text)
        assert result
      end
    end
  end

  def test_copy_with_very_long_text
    long_text = "x" * 10000

    # Create a simple mock clipboard
    mock_clipboard = Object.new
    def mock_clipboard.text=(val)
      @text = val
    end

    def mock_clipboard.respond_to?(method)
      method == :store
    end

    def mock_clipboard.store
    end

    Gdk::Display.stub :default, @mock_display do
      Gtk::Clipboard.stub :get_default, mock_clipboard do
        result = Kindling::Clipboard.copy(long_text)
        assert result
      end
    end
  end
end
