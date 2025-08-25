# frozen_string_literal: true

require_relative "../test_helper"

class IndexBackendsTest < Minitest::Test
  def test_available_checks_for_fd_or_rg
    # At least one of fd or rg should be available in CI
    assert Kindling::IndexBackends.available? || !system("which fd") && !system("which rg")
  end

  def test_find_fd_returns_path_or_nil
    result = Kindling::IndexBackends.find_fd
    if result
      assert_kind_of String, result
      assert File.executable?(result)
    else
      assert_nil result
    end
  end

  def test_find_rg_returns_path_or_nil
    result = Kindling::IndexBackends.find_rg
    if result
      assert_kind_of String, result
      assert File.executable?(result)
    else
      assert_nil result
    end
  end

  def test_run_fd_with_files
    skip "fd not available" unless Kindling::IndexBackends.find_fd

    with_temp_dir do |dir|
      create_files(dir, {
        "file1.txt" => "content",
        "file2.rb" => "code",
        ".hidden" => "hidden",
        "subdir" => {
          "file3.md" => "markdown"
        }
      })

      enum = Kindling::IndexBackends.run_fd(dir)
      assert_kind_of Enumerator, enum

      files = enum.to_a
      assert files.include?("file1.txt")
      assert files.include?("file2.rb")
      assert files.include?(".hidden")
      assert files.include?("subdir/file3.md")
    end
  end

  def test_run_fd_excludes_git_directory
    skip "fd not available" unless Kindling::IndexBackends.find_fd

    with_temp_dir do |dir|
      create_files(dir, {
        ".git" => {
          "config" => "git config"
        },
        "file.txt" => "content"
      })

      enum = Kindling::IndexBackends.run_fd(dir)
      files = enum.to_a

      assert files.include?("file.txt")
      assert !files.any? { |f| f.start_with?(".git") }
    end
  end

  def test_run_fd_respects_gitignore_flag
    skip "fd not available" unless Kindling::IndexBackends.find_fd

    with_temp_dir do |dir|
      create_files(dir, {
        ".gitignore" => "*.log",
        "file.txt" => "content",
        "debug.log" => "log"
      })

      # With gitignore respect
      enum = Kindling::IndexBackends.run_fd(dir, respect_gitignore: true)
      files = enum.to_a
      assert files.include?("file.txt")
      assert !files.include?("debug.log")

      # Without gitignore respect
      enum = Kindling::IndexBackends.run_fd(dir, respect_gitignore: false)
      files = enum.to_a
      assert files.include?("file.txt")
      assert files.include?("debug.log")
    end
  end

  def test_run_rg_with_files
    skip "rg not available" unless Kindling::IndexBackends.find_rg

    with_temp_dir do |dir|
      create_files(dir, {
        "file1.txt" => "content",
        "file2.rb" => "code",
        ".hidden" => "hidden",
        "subdir" => {
          "file3.md" => "markdown"
        }
      })

      enum = Kindling::IndexBackends.run_rg(dir)
      assert_kind_of Enumerator, enum

      files = enum.to_a
      assert files.include?("file1.txt")
      assert files.include?("file2.rb")
      assert files.include?(".hidden")
      assert files.include?("subdir/file3.md")
    end
  end

  def test_run_rg_excludes_patterns
    skip "rg not available" unless Kindling::IndexBackends.find_rg

    with_temp_dir do |dir|
      create_files(dir, {
        ".git" => {
          "config" => "git config"
        },
        "node_modules" => {
          "package" => {
            "index.js" => "code"
          }
        },
        "file.txt" => "content",
        ".DS_Store" => "mac file"
      })

      enum = Kindling::IndexBackends.run_rg(dir)
      files = enum.to_a

      assert files.include?("file.txt")
      assert !files.any? { |f| f.start_with?(".git") }
      assert !files.any? { |f| f.start_with?("node_modules") }
      assert !files.include?(".DS_Store")
    end
  end

  def test_normalize_rel_removes_dot_slash
    result = Kindling::IndexBackends.normalize_rel("/root", "./file.txt")
    assert_equal "file.txt", result

    result = Kindling::IndexBackends.normalize_rel("/root", "file.txt")
    assert_equal "file.txt", result
  end

  def test_normalize_rel_handles_absolute_paths
    result = Kindling::IndexBackends.normalize_rel("/root", "/root/subdir/file.txt")
    assert_equal "subdir/file.txt", result
  end

  def test_which_finds_executable
    # Test with a command that should exist
    result = Kindling::IndexBackends.which("ls")
    assert_kind_of String, result
    assert File.executable?(result)
  end

  def test_which_returns_nil_for_nonexistent
    result = Kindling::IndexBackends.which("nonexistent_command_xyz")
    assert_nil result
  end

  def test_run_streaming_handles_errors
    # run_streaming returns an Enumerator even on error, but it will be empty or raise when used
    enum = Kindling::IndexBackends.run_streaming("/", ["nonexistent_command"], nul_sep: false)
    # The enumerator exists but should fail or be empty when used
    assert_kind_of Enumerator, enum

    # Trying to get values should handle the error gracefully
    result = begin
      enum.to_a
    rescue
      []
    end
    assert_equal [], result
  end
end
