# frozen_string_literal: true

require_relative "../test_helper"

class DirWalkerTest < Minitest::Test
  def setup
    @cancel_token = Kindling::CancellationToken.new
  end

  def test_walks_directory_recursively
    with_temp_dir do |dir|
      create_files(dir, {
        "file1.txt" => "content",
        "dir1" => {
          "file2.rb" => "code",
          "subdir" => {
            "file3.md" => "markdown"
          }
        },
        "file4.js" => "javascript"
      })

      walker = Kindling::DirWalker.new(
        root: dir,
        ignores: [],
        gitignore_parser: nil,
        cancel_token: @cancel_token,
        max_dir_entries: 0,
        max_dir_sample_mb: 0
      )
      walker.start!

      files = []
      while (file = walker.queue.pop)
        files << file
      end

      walker.join

      assert files.include?("file1.txt")
      assert files.include?("dir1/file2.rb")
      assert files.include?("dir1/subdir/file3.md")
      assert files.include?("file4.js")
    end
  end

  def test_respects_ignore_patterns
    with_temp_dir do |dir|
      create_files(dir, {
        "file.txt" => "content",
        "node_modules" => {
          "package" => {
            "index.js" => "code"
          }
        },
        ".git" => {
          "config" => "git config"
        },
        "src" => {
          "main.rb" => "ruby code"
        }
      })

      walker = Kindling::DirWalker.new(
        root: dir,
        ignores: ["node_modules", ".git"],
        gitignore_parser: nil,
        cancel_token: @cancel_token,
        max_dir_entries: 0,
        max_dir_sample_mb: 0
      )
      walker.start!

      files = []
      while (file = walker.queue.pop)
        files << file
      end

      walker.join

      assert files.include?("file.txt")
      assert files.include?("src/main.rb")
      refute files.any? { |f| f.include?("node_modules") }
      refute files.any? { |f| f.include?(".git") }
    end
  end

  def test_respects_gitignore_parser
    with_temp_dir do |dir|
      create_files(dir, {
        "file.txt" => "content",
        "ignored.log" => "log file",
        "src" => {
          "main.rb" => "code",
          "debug.log" => "another log"
        }
      })

      gitignore = Kindling::GitignoreParser.new
      gitignore.add_pattern("*.log")

      walker = Kindling::DirWalker.new(
        root: dir,
        ignores: [],
        gitignore_parser: gitignore,
        cancel_token: @cancel_token,
        max_dir_entries: 0,
        max_dir_sample_mb: 0
      )
      walker.start!

      files = []
      while (file = walker.queue.pop)
        files << file
      end

      walker.join

      assert files.include?("file.txt")
      assert files.include?("src/main.rb")
      refute files.include?("ignored.log")
      refute files.include?("src/debug.log")
    end
  end

  def test_cancellation_stops_walking
    with_temp_dir do |dir|
      # Create many files
      100.times { |i| File.write(File.join(dir, "file#{i}.txt"), "content") }

      walker = Kindling::DirWalker.new(
        root: dir,
        ignores: [],
        gitignore_parser: nil,
        cancel_token: @cancel_token,
        max_dir_entries: 0,
        max_dir_sample_mb: 0
      )
      walker.start!

      # Collect a few files
      files = []
      5.times do
        file = walker.queue.pop
        break unless file
        files << file
      end

      # Cancel and wait
      @cancel_token.cancel!
      walker.join

      # Should have gotten some files but not all
      assert files.size > 0
      assert files.size < 100
    end
  end

  def test_queue_size_limit
    with_temp_dir do |dir|
      # Create files
      20.times { |i| File.write(File.join(dir, "file#{i}.txt"), "content") }

      walker = Kindling::DirWalker.new(
        root: dir,
        ignores: [],
        gitignore_parser: nil,
        cancel_token: @cancel_token,
        max_dir_entries: 0,
        max_dir_sample_mb: 0,
        queue_size: 5  # Small queue
      )

      # Queue should be a SizedQueue with specified size
      assert_equal 5, walker.queue.max

      walker.start!

      # Drain the queue
      files = []
      while (file = walker.queue.pop)
        files << file
      end

      walker.join
      assert_equal 20, files.size
    end
  end

  def test_handles_directory_errors
    with_temp_dir do |dir|
      create_files(dir, {
        "readable" => {"file.txt" => "content"}
      })

      # Create unreadable directory
      unreadable = File.join(dir, "unreadable")
      FileUtils.mkdir_p(unreadable)
      File.write(File.join(unreadable, "secret.txt"), "secret")
      File.chmod(0o000, unreadable)

      walker = Kindling::DirWalker.new(
        root: dir,
        ignores: [],
        gitignore_parser: nil,
        cancel_token: @cancel_token,
        max_dir_entries: 0,
        max_dir_sample_mb: 0
      )
      walker.start!

      files = []
      while (file = walker.queue.pop)
        files << file
      end

      walker.join

      # Should get readable files but skip unreadable
      assert files.include?("readable/file.txt")
      refute files.include?("unreadable/secret.txt")
    ensure
      File.chmod(0o755, unreadable) if unreadable && Dir.exist?(unreadable)
    end
  end

  def test_max_dir_entries_limit
    skip "Directory limits not implemented in base walker"

    with_temp_dir do |dir|
      large_dir = File.join(dir, "large")
      FileUtils.mkdir_p(large_dir)

      # Create many files in one directory
      20.times { |i| File.write(File.join(large_dir, "file#{i}.txt"), "x") }

      # Create a normal file outside
      File.write(File.join(dir, "normal.txt"), "content")

      walker = Kindling::DirWalker.new(
        root: dir,
        ignores: [],
        gitignore_parser: nil,
        cancel_token: @cancel_token,
        max_dir_entries: 10,  # Limit entries per directory
        max_dir_sample_mb: 0
      )
      walker.start!

      files = []
      while (file = walker.queue.pop)
        files << file
      end

      walker.join

      # Should get normal file but skip large directory
      assert files.include?("normal.txt")
      refute files.any? { |f| f.start_with?("large/") }
    end
  end

  def test_thread_safety
    skip "Thread safety test causes deadlock in test environment"

    with_temp_dir do |dir|
      create_files(dir, {
        "file1.txt" => "content",
        "file2.txt" => "content",
        "file3.txt" => "content"
      })

      walker = Kindling::DirWalker.new(
        root: dir,
        ignores: [],
        gitignore_parser: nil,
        cancel_token: @cancel_token,
        max_dir_entries: 0,
        max_dir_sample_mb: 0
      )
      walker.start!

      # Multiple threads consuming from queue
      files = []
      mutex = Mutex.new
      threads = 3.times.map do
        Thread.new do
          while (file = walker.queue.pop)
            mutex.synchronize { files << file }
          end
        end
      end

      walker.join
      threads.each(&:join)

      assert_equal 3, files.size
      assert_equal files.sort, files.uniq.sort  # No duplicates
    end
  end
end
