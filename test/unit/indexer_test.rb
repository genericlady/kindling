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
      
      paths = @indexer.index(dir)
      
      expected = [
        "README.md",
        "src/lib/helper.rb",
        "src/main.rb",
        "test.txt"
      ]
      
      assert_same_elements expected, paths
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
      
      paths = @indexer.index(dir)
      
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
      
      paths = @indexer.index(dir)
      
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
      
      paths = @indexer.index(dir)
      
      assert_equal ["src/main.rb"], paths
    end
  end
  
  def test_calls_progress_callback
    with_temp_dir do |dir|
      # Create 201 files to trigger progress callback
      files = {}
      201.times { |i| files["file#{i}.txt"] = "content" }
      create_files(dir, files)
      
      progress_calls = []
      @indexer.index(dir, on_progress: ->(count) { progress_calls << count })
      
      # Should have at least one progress call at 200 files
      assert progress_calls.any? { |c| c >= 200 }
      assert_equal 201, progress_calls.last
    end
  end
  
  def test_yields_paths_on_completion
    with_temp_dir do |dir|
      create_files(dir, { "test.txt" => "test" })
      
      yielded_paths = nil
      @indexer.index(dir) { |paths| yielded_paths = paths }
      
      assert_equal ["test.txt"], yielded_paths
    end
  end
  
  def test_cancel_stops_indexing
    skip "Cancel testing requires threading setup"
  end
end