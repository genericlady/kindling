# frozen_string_literal: true

require_relative "../test_helper"

class UIWindowTest < Minitest::Test
  def setup
    @mock_app = Minitest::Mock.new
    # Mock GTK Application methods that Window might call
    @mock_app.expect(:is_a?, true, [Gtk::Application])

    # Skip these tests if GTK is not properly initialized
    skip "GTK not available in test environment" unless gtk_available?
  end

  def gtk_available?
    # Check if GTK is properly initialized

    Gtk.respond_to?(:init) && defined?(Gtk::ApplicationWindow)
  rescue
    false
  end

  def test_window_initialization
    window = Kindling::UI::Window.new(@mock_app)

    assert_instance_of Kindling::UI::Window, window
    assert_kind_of Gtk::ApplicationWindow, window
  end

  def test_window_sets_default_properties
    window = Kindling::UI::Window.new(@mock_app)

    assert_equal "Kindling", window.title
    # Default size is set but GTK may adjust it
    assert window.default_width > 0
    assert window.default_height > 0
  end

  def test_on_folder_chosen_callback
    window = Kindling::UI::Window.new(@mock_app)

    callback_called = false
    window.on_folder_chosen { callback_called = true }

    # Trigger the callback through the instance variable
    callbacks = window.instance_variable_get(:@callbacks)
    callbacks[:folder_chosen]&.call

    assert callback_called
  end

  def test_on_search_changed_callback
    window = Kindling::UI::Window.new(@mock_app)

    received_query = nil
    window.on_search_changed { |query| received_query = query }

    callbacks = window.instance_variable_get(:@callbacks)
    callbacks[:search_changed]&.call("test")

    assert_equal "test", received_query
  end

  def test_on_selection_changed_callback
    window = Kindling::UI::Window.new(@mock_app)

    received_paths = nil
    window.on_selection_changed { |paths| received_paths = paths }

    callbacks = window.instance_variable_get(:@callbacks)
    test_paths = ["file1.rb", "file2.rb"]
    callbacks[:selection_changed]&.call(test_paths)

    assert_equal test_paths, received_paths
  end

  def test_on_copy_requested_callback
    window = Kindling::UI::Window.new(@mock_app)

    callback_called = false
    window.on_copy_requested { callback_called = true }

    callbacks = window.instance_variable_get(:@callbacks)
    callbacks[:copy_requested]&.call

    assert callback_called
  end

  def test_on_include_contents_changed_callback
    window = Kindling::UI::Window.new(@mock_app)

    received_value = nil
    window.on_include_contents_changed { |val| received_value = val }

    callbacks = window.instance_variable_get(:@callbacks)
    callbacks[:include_contents_changed]&.call(true)

    assert_equal true, received_value
  end

  def test_update_progress_delegates_to_header
    window = Kindling::UI::Window.new(@mock_app)

    mock_header = Minitest::Mock.new
    mock_header.expect(:update_progress, nil, ["Processing..."])
    window.instance_variable_set(:@header, mock_header)

    window.update_progress("Processing...")

    mock_header.verify
  end

  def test_show_progress_loader_delegates_to_header
    window = Kindling::UI::Window.new(@mock_app)

    mock_header = Minitest::Mock.new
    mock_header.expect(:show_progress_loader, nil)
    window.instance_variable_set(:@header, mock_header)

    window.show_progress_loader

    mock_header.verify
  end

  def test_hide_progress_loader_delegates_to_header
    window = Kindling::UI::Window.new(@mock_app)

    mock_header = Minitest::Mock.new
    mock_header.expect(:hide_progress_loader, nil)
    window.instance_variable_set(:@header, mock_header)

    window.hide_progress_loader

    mock_header.verify
  end

  def test_update_file_list_delegates_to_file_list
    window = Kindling::UI::Window.new(@mock_app)

    mock_file_list = Minitest::Mock.new
    paths = ["file1.rb", "file2.rb"]
    mock_file_list.expect(:update_files, nil, [paths])
    window.instance_variable_set(:@file_list, mock_file_list)

    window.update_file_list(paths)

    mock_file_list.verify
  end

  def test_update_preview_delegates_to_preview
    window = Kindling::UI::Window.new(@mock_app)

    mock_preview = Minitest::Mock.new
    content = "preview content"
    mock_preview.expect(:update_content, nil, [content])
    window.instance_variable_set(:@preview, mock_preview)

    window.update_preview(content)

    mock_preview.verify
  end

  def test_enable_copy_button_delegates_to_header
    window = Kindling::UI::Window.new(@mock_app)

    mock_header = Minitest::Mock.new
    mock_header.expect(:enable_copy_button, nil)
    window.instance_variable_set(:@header, mock_header)

    window.enable_copy_button

    mock_header.verify
  end

  def test_disable_copy_button_delegates_to_header
    window = Kindling::UI::Window.new(@mock_app)

    mock_header = Minitest::Mock.new
    mock_header.expect(:disable_copy_button, nil)
    window.instance_variable_set(:@header, mock_header)

    window.disable_copy_button

    mock_header.verify
  end

  def test_flash_success_updates_title_temporarily
    window = Kindling::UI::Window.new(@mock_app)

    window.title

    # Mock GLib::Timeout
    GLib::Timeout.stub :add, 123 do
      window.flash_success("✓ Copied")
    end

    assert_equal "Kindling — ✓ Copied", window.title
  end

  def test_clear_file_selections_delegates_to_file_list
    window = Kindling::UI::Window.new(@mock_app)

    mock_file_list = Minitest::Mock.new
    mock_file_list.expect(:clear_selections, nil)
    window.instance_variable_set(:@file_list, mock_file_list)

    window.clear_file_selections

    mock_file_list.verify
  end

  def test_show_file_list_loading_delegates_to_file_list
    window = Kindling::UI::Window.new(@mock_app)

    mock_file_list = Minitest::Mock.new
    mock_file_list.expect(:show_loading, nil)
    window.instance_variable_set(:@file_list, mock_file_list)

    window.show_file_list_loading

    mock_file_list.verify
  end

  def test_hide_file_list_loading_delegates_to_file_list
    window = Kindling::UI::Window.new(@mock_app)

    mock_file_list = Minitest::Mock.new
    mock_file_list.expect(:hide_loading, nil)
    window.instance_variable_set(:@file_list, mock_file_list)

    window.hide_file_list_loading

    mock_file_list.verify
  end
end
