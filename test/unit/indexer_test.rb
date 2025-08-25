# frozen_string_literal: true

require_relative "../test_helper"

class IndexerTest < Minitest::Test
  def setup
    @indexer = Kindling::Indexer.new
  end

  def test_indexes_files_recursively
    with_temp_dir do |dir|
      create_files(dir, {
        "src" => {
          "main.rb" => "puts 'hello'",
          "lib" => {
            "helper.rb" => "# helper"
          }
        },
        "README.md" => "# Test",
        "test.txt" => "test"
      })

      # Collect all batches
      all_batches = []
      paths = @indexer.index(dir) { |batch| all_batches.concat(batch) }

      expected = [
        "README.md",
        "src/lib/helper.rb",
        "src/main.rb",
        "test.txt"
      ]

      assert_same_elements expected, paths
      # Also check batches were yielded
      assert_same_elements expected, all_batches
    end
  end

  def test_ignores_git_directory
    with_temp_dir do |dir|
      create_files(dir, {
        ".git" => {
          "config" => "git config",
          "HEAD" => "ref: refs/heads/main"
        },
        "src" => {
          "main.rb" => "code"
        }
      })

      paths = @indexer.index(dir) { |batch| }

      assert_equal ["src/main.rb"], paths
    end
  end

  def test_ignores_node_modules
    with_temp_dir do |dir|
      create_files(dir, {
        "node_modules" => {
          "package" => {
            "index.js" => "module.exports = {}"
          }
        },
        "app.js" => "console.log('app')"
      })

      paths = @indexer.index(dir) { |batch| }

      assert_equal ["app.js"], paths
    end
  end

  def test_ignores_ds_store_files
    with_temp_dir do |dir|
      create_files(dir, {
        ".DS_Store" => "",
        "src" => {
          ".DS_Store" => "",
          "main.rb" => "code"
        }
      })

      paths = @indexer.index(dir) { |batch| }

      assert_equal ["src/main.rb"], paths
    end
  end

  def test_calls_progress_callback
    with_temp_dir do |dir|
      # Create enough files to trigger batching
      files = {}
      25.times { |i| files["file#{i}.txt"] = "content" }
      create_files(dir, files)

      progress_calls = []
      batch_count = 0
      @indexer.index(dir, on_progress: ->(count) { progress_calls << count }) do |batch|
        batch_count += 1
      end

      # Should have received progress updates
      assert !progress_calls.empty?, "Expected progress callbacks"
      assert_equal 25, progress_calls.last
      # Should have received at least one batch
      assert batch_count > 0, "Expected batches to be yielded"
    end
  end

  def test_yields_batches_during_indexing
    with_temp_dir do |dir|
      create_files(dir, {"test.txt" => "test", "other.rb" => "code"})

      batches = []
      result = @indexer.index(dir) { |batch| batches << batch.dup }

      # Should return all paths
      assert_same_elements ["test.txt", "other.rb"], result
      # Should have yielded batches
      all_from_batches = batches.flatten
      assert_same_elements ["test.txt", "other.rb"], all_from_batches
    end
  end

  def test_cancel_stops_indexing
    skip "Cancel testing requires threading setup"
  end

  def test_respects_gitignore_file
    with_temp_dir do |dir|
      create_files(dir, {
        ".gitignore" => "*.log\nbuild/\nsecret.txt",
        "app.rb" => "app code",
        "test.log" => "log file",
        "debug.log" => "debug log",
        "build" => {
          "output.js" => "compiled"
        },
        "src" => {
          "main.rb" => "main",
          "test.log" => "nested log"
        },
        "secret.txt" => "secret"
      })

      indexer = Kindling::Indexer.new(use_gitignore: true)
      paths = indexer.index(dir) { |batch| }

      # Should include app.rb and src/main.rb
      # Should NOT include any .log files, build/, or secret.txt
      assert paths.include?("app.rb")
      assert paths.include?("src/main.rb")
      assert paths.include?(".gitignore") # .gitignore itself is not ignored

      assert !paths.include?("test.log")
      assert !paths.include?("debug.log")
      assert !paths.include?("src/test.log")
      assert !paths.include?("build/output.js")
      assert !paths.include?("secret.txt")
    end
  end

  def test_skips_large_directories
    # Skip this test since default is now unlimited - this is the desired behavior
    skip "Directory limits are disabled by default (unlimited indexing)"
  end

  def test_can_disable_gitignore
    with_temp_dir do |dir|
      create_files(dir, {
        ".gitignore" => "*.log",
        "test.log" => "log file"
      })

      indexer = Kindling::Indexer.new(use_gitignore: false)
      paths = indexer.index(dir) { |batch| }

      # Should include the .log file when gitignore is disabled
      assert paths.include?("test.log")
      assert paths.include?(".gitignore")
    end
  end
end
