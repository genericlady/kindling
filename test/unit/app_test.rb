# frozen_string_literal: true

require_relative "../test_helper"

class AppTest < Minitest::Test
  def setup
    @app = Kindling::App.new
    @mock_gtk_app = Minitest::Mock.new
    @mock_window = Minitest::Mock.new
  end

  def test_class_run_method
    mock_instance = Minitest::Mock.new
    mock_instance.expect(:run, nil, [[]])

    Kindling::App.stub :new, mock_instance do
      Kindling::App.run([])
    end

    mock_instance.verify
  end

  def test_initialize_sets_defaults
    app = Kindling::App.new

    # Check instance variables are initialized
    assert_instance_of Gtk::Application, app.instance_variable_get(:@app)
    assert_nil app.instance_variable_get(:@window)
    assert_empty app.instance_variable_get(:@paths)
    assert_instance_of Kindling::Selection, app.instance_variable_get(:@selected_paths)
    assert_nil app.instance_variable_get(:@indexer)
    assert_equal 0, app.instance_variable_get(:@index_generation)
    refute app.instance_variable_get(:@include_contents)
    assert_nil app.instance_variable_get(:@current_root)
    assert_nil app.instance_variable_get(:@loading_timer_id)
  end

  def test_run_connects_signals
    # Mock the GTK application
    @mock_gtk_app.expect(:signal_connect, nil, ["startup"])
    @mock_gtk_app.expect(:signal_connect, nil, ["activate"])
    @mock_gtk_app.expect(:run, nil, [[]])

    app = Kindling::App.new
    app.instance_variable_set(:@app, @mock_gtk_app)

    app.run([])

    @mock_gtk_app.verify
  end

  def test_detect_language_ruby
    app = Kindling::App.new

    assert_equal "ruby", app.send(:detect_language, "test.rb")
    assert_equal "ruby", app.send(:detect_language, "Rakefile")
    assert_equal "ruby", app.send(:detect_language, "Gemfile")
    assert_equal "ruby", app.send(:detect_language, "test.rake")
  end

  def test_detect_language_javascript
    app = Kindling::App.new

    assert_equal "javascript", app.send(:detect_language, "app.js")
    assert_equal "javascript", app.send(:detect_language, "component.jsx")
  end

  def test_detect_language_typescript
    app = Kindling::App.new

    assert_equal "typescript", app.send(:detect_language, "app.ts")
    assert_equal "typescript", app.send(:detect_language, "component.tsx")
  end

  def test_detect_language_python
    app = Kindling::App.new
    assert_equal "python", app.send(:detect_language, "script.py")
  end

  def test_detect_language_various
    app = Kindling::App.new

    assert_equal "go", app.send(:detect_language, "main.go")
    assert_equal "rust", app.send(:detect_language, "lib.rs")
    assert_equal "java", app.send(:detect_language, "Main.java")
    assert_equal "cpp", app.send(:detect_language, "main.cpp")
    assert_equal "c", app.send(:detect_language, "main.c")
    assert_equal "csharp", app.send(:detect_language, "Program.cs")
  end

  def test_detect_language_web
    app = Kindling::App.new

    assert_equal "html", app.send(:detect_language, "index.html")
    assert_equal "css", app.send(:detect_language, "style.css")
    assert_equal "scss", app.send(:detect_language, "style.scss")
    assert_equal "json", app.send(:detect_language, "config.json")
    assert_equal "yaml", app.send(:detect_language, "config.yaml")
    assert_equal "xml", app.send(:detect_language, "data.xml")
  end

  def test_detect_language_shell
    app = Kindling::App.new

    assert_equal "bash", app.send(:detect_language, "script.sh")
    assert_equal "bash", app.send(:detect_language, "script.bash")
    assert_equal "zsh", app.send(:detect_language, "script.zsh")
    assert_equal "fish", app.send(:detect_language, "script.fish")
    assert_equal "powershell", app.send(:detect_language, "script.ps1")
  end

  def test_detect_language_special_files
    app = Kindling::App.new

    assert_equal "makefile", app.send(:detect_language, "Makefile")
    assert_equal "makefile", app.send(:detect_language, "GNUmakefile")
    assert_equal "dockerfile", app.send(:detect_language, "Dockerfile")
    assert_equal "json", app.send(:detect_language, "package.json")
    assert_equal "json", app.send(:detect_language, "tsconfig.json")
    assert_equal "gitignore", app.send(:detect_language, ".gitignore")
    assert_equal "gitignore", app.send(:detect_language, ".dockerignore")
  end

  def test_detect_language_other_languages
    app = Kindling::App.new

    assert_equal "php", app.send(:detect_language, "index.php")
    assert_equal "swift", app.send(:detect_language, "App.swift")
    assert_equal "kotlin", app.send(:detect_language, "Main.kt")
    assert_equal "scala", app.send(:detect_language, "Main.scala")
    assert_equal "sql", app.send(:detect_language, "query.sql")
    assert_equal "markdown", app.send(:detect_language, "README.md")
    assert_equal "lua", app.send(:detect_language, "script.lua")
    assert_equal "perl", app.send(:detect_language, "script.pl")
    assert_equal "elixir", app.send(:detect_language, "app.ex")
    assert_equal "clojure", app.send(:detect_language, "core.clj")
    assert_equal "haskell", app.send(:detect_language, "Main.hs")
    assert_equal "vue", app.send(:detect_language, "App.vue")
    assert_equal "svelte", app.send(:detect_language, "App.svelte")
  end

  def test_detect_language_unknown
    app = Kindling::App.new

    assert_equal "", app.send(:detect_language, "unknown.xyz")
    assert_equal "", app.send(:detect_language, "noextension")
  end

  def test_format_file_contents_with_readable_file
    app = Kindling::App.new
    app.instance_variable_set(:@current_root, "/tmp/test")

    # Create a temp file
    Dir.mktmpdir do |dir|
      app.instance_variable_set(:@current_root, dir)

      File.write(File.join(dir, "test.rb"), "puts 'Hello'")

      result = app.send(:format_file_contents, ["test.rb"])

      assert_includes result, "## test.rb"
      assert_includes result, "```ruby"
      assert_includes result, "puts 'Hello'"
      assert_includes result, "```"
    end
  end

  def test_format_file_contents_skips_directories
    app = Kindling::App.new

    Dir.mktmpdir do |dir|
      app.instance_variable_set(:@current_root, dir)

      # Create a subdirectory
      subdir = File.join(dir, "subdir")
      Dir.mkdir(subdir)

      result = app.send(:format_file_contents, ["subdir"])

      assert_empty result
    end
  end

  def test_format_file_contents_handles_read_error
    app = Kindling::App.new

    Dir.mktmpdir do |dir|
      app.instance_variable_set(:@current_root, dir)

      # Create unreadable file (will simulate error)
      file_path = File.join(dir, "test.txt")
      File.write(file_path, "content")

      # Mock File.read to raise an error
      File.stub :read, proc { raise "Permission denied" } do
        result = app.send(:format_file_contents, ["test.txt"])

        assert_includes result, "## test.txt"
        assert_includes result, "[Error reading file: Permission denied]"
      end
    end
  end

  def test_format_file_contents_with_unicode
    app = Kindling::App.new

    Dir.mktmpdir do |dir|
      app.instance_variable_set(:@current_root, dir)

      File.write(File.join(dir, "unicode.txt"), "Hello 世界 🌍", encoding: "UTF-8")

      result = app.send(:format_file_contents, ["unicode.txt"])

      assert_includes result, "Hello 世界 🌍"
      assert_equal Encoding::UTF_8, result.encoding
    end
  end

  def test_format_file_contents_multiple_files
    app = Kindling::App.new

    Dir.mktmpdir do |dir|
      app.instance_variable_set(:@current_root, dir)

      File.write(File.join(dir, "file1.rb"), "puts 1")
      File.write(File.join(dir, "file2.py"), "print(2)")

      result = app.send(:format_file_contents, ["file1.rb", "file2.py"])

      assert_includes result, "## file1.rb"
      assert_includes result, "```ruby"
      assert_includes result, "puts 1"

      assert_includes result, "## file2.py"
      assert_includes result, "```python"
      assert_includes result, "print(2)"
    end
  end

  def test_cancel_loading_timer_when_nil
    app = Kindling::App.new
    app.instance_variable_set(:@loading_timer_id, nil)

    # Should not raise error
    app.send(:cancel_loading_timer!)

    assert_nil app.instance_variable_get(:@loading_timer_id)
  end

  def test_cancel_loading_timer_with_timer
    app = Kindling::App.new
    app.instance_variable_set(:@loading_timer_id, 123)

    GLib::Source.stub :remove, true do
      app.send(:cancel_loading_timer!)
    end

    assert_nil app.instance_variable_get(:@loading_timer_id)
  end

  def test_update_selection_with_paths
    app = Kindling::App.new
    app.instance_variable_set(:@window, @mock_window)

    paths = ["file1.rb", "file2.rb"]
    tree = "mocked tree"

    # Set expectations
    @mock_window.expect(:update_preview, nil, [tree])
    @mock_window.expect(:enable_copy_button, nil)

    Kindling::TreeRenderer.stub :render, tree do
      app.send(:update_selection, paths)
    end

    # Verify selection was updated
    selection = app.instance_variable_get(:@selected_paths)
    assert_equal paths.sort, selection.to_a

    @mock_window.verify
  end

  def test_update_selection_empty
    app = Kindling::App.new
    app.instance_variable_set(:@window, @mock_window)

    # Set expectations
    @mock_window.expect(:update_preview, nil, [""])
    @mock_window.expect(:disable_copy_button, nil)

    app.send(:update_selection, [])

    # Verify selection was cleared
    selection = app.instance_variable_get(:@selected_paths)
    assert_empty selection

    @mock_window.verify
  end

  def test_filter_files_with_empty_query
    app = Kindling::App.new
    app.instance_variable_set(:@window, @mock_window)

    paths = (1..20000).map { |i| "file#{i}.rb" }
    app.instance_variable_set(:@paths, paths)

    # Should return first 10000
    @mock_window.expect(:update_file_list, nil) do |filtered|
      filtered.size == 10000
    end

    app.send(:filter_files, "")

    @mock_window.verify
  end

  def test_filter_files_with_query
    app = Kindling::App.new
    app.instance_variable_set(:@window, @mock_window)

    paths = ["app.rb", "test.rb", "config.yml"]
    app.instance_variable_set(:@paths, paths)

    # Mock Fuzzy.filter
    filtered_result = ["app.rb", "test.rb"]

    @mock_window.expect(:update_file_list, nil, [filtered_result])

    Kindling::Fuzzy.stub :filter, filtered_result do
      app.send(:filter_files, "rb")
    end

    @mock_window.verify
  end

  def test_copy_tree_to_clipboard_success
    app = Kindling::App.new
    app.instance_variable_set(:@window, @mock_window)

    selection = Kindling::Selection.new
    selection.add("file1.rb")
    app.instance_variable_set(:@selected_paths, selection)

    tree = "mocked tree"

    @mock_window.expect(:flash_success, nil, ["✓ Copied"])

    Kindling::TreeRenderer.stub :render, tree do
      Kindling::Clipboard.stub :copy, true do
        app.send(:copy_tree_to_clipboard)
      end
    end

    @mock_window.verify
  end

  def test_copy_tree_to_clipboard_with_contents
    app = Kindling::App.new
    app.instance_variable_set(:@window, @mock_window)
    app.instance_variable_set(:@include_contents, true)

    Dir.mktmpdir do |dir|
      app.instance_variable_set(:@current_root, dir)

      File.write(File.join(dir, "test.rb"), "puts 'test'")

      selection = Kindling::Selection.new
      selection.add("test.rb")
      app.instance_variable_set(:@selected_paths, selection)

      @mock_window.expect(:flash_success, nil, ["✓ Copied with contents"])

      Kindling::Clipboard.stub :copy, true do
        app.send(:copy_tree_to_clipboard)
      end

      @mock_window.verify
    end
  end

  def test_copy_tree_to_clipboard_empty_selection
    app = Kindling::App.new
    app.instance_variable_set(:@selected_paths, Kindling::Selection.new)

    # Should return early without doing anything
    result = app.send(:copy_tree_to_clipboard)
    assert_nil result
  end

  def test_copy_tree_to_clipboard_failure
    app = Kindling::App.new
    app.instance_variable_set(:@window, @mock_window)

    selection = Kindling::Selection.new
    selection.add("file1.rb")
    app.instance_variable_set(:@selected_paths, selection)

    # No flash_success expectation since copy fails

    Kindling::TreeRenderer.stub :render, "tree" do
      Kindling::Clipboard.stub :copy, false do
        app.send(:copy_tree_to_clipboard)
      end
    end

    # No verify needed since mock_window has no expectations
  end
end
