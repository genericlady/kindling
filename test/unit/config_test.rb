# frozen_string_literal: true

require_relative "../test_helper"

class ConfigTest < Minitest::Test
  def setup
    # Store original ENV value
    @original_debug = ENV["KINDLING_DEBUG"]
  end

  def teardown
    # Restore original ENV value
    if @original_debug
      ENV["KINDLING_DEBUG"] = @original_debug
    else
      ENV.delete("KINDLING_DEBUG")
    end
  end

  def test_constants_defined
    assert_equal 500_000, Kindling::Config::MAX_FILES  # New default
    assert_equal 5_000, Kindling::Config::MAX_VISIBLE_RESULTS
    assert_equal 1_000, Kindling::Config::MAX_PREVIEW_PATHS
    assert_equal 200, Kindling::Config::DEBOUNCE_MS
    assert_equal 1000, Kindling::Config::PROGRESS_UPDATE_INTERVAL
    assert_equal 250, Kindling::Config::MAX_DIR_SIZE_MB  # New default
    assert_equal 15_000, Kindling::Config::MAX_DIR_FILE_COUNT  # New default
    assert_equal 2000, Kindling::Config::MAX_MEMORY_MB
    assert_equal 2000, Kindling::Config::BATCH_SIZE  # New constant
    assert_equal 10_000, Kindling::Config::WALK_QUEUE_SIZE  # New constant
    assert_equal :auto, Kindling::Config::INDEX_BACKEND  # New constant
    assert_equal 1200, Kindling::Config::WINDOW_WIDTH
    assert_equal 800, Kindling::Config::WINDOW_HEIGHT
    assert_equal 0.6, Kindling::Config::PANE_POSITION
    assert_equal 1, Kindling::Config::MIN_QUERY_LENGTH
    assert_equal 2, Kindling::Config::PREFIX_SEARCH_THRESHOLD
  end

  def test_additional_ignores_empty_by_default
    assert_empty Kindling::Config::ADDITIONAL_IGNORES
  end

  def test_ignore_patterns_includes_indexer_defaults
    patterns = Kindling::Config.ignore_patterns
    assert_includes patterns, ".git"
    assert_includes patterns, "node_modules"
    assert_includes patterns, ".DS_Store"
  end

  def test_ignore_patterns_includes_additional_ignores
    # This would require modifying the constant, which we shouldn't do in tests
    # Instead, we verify the method combines both arrays
    assert_equal(
      Kindling::Indexer::DEFAULT_IGNORES + Kindling::Config::ADDITIONAL_IGNORES,
      Kindling::Config.ignore_patterns
    )
  end

  def test_debug_false_by_default
    ENV.delete("KINDLING_DEBUG")
    refute Kindling::Config.debug?
  end

  def test_debug_true_when_env_is_true
    ENV["KINDLING_DEBUG"] = "true"
    assert Kindling::Config.debug?
  end

  def test_debug_true_when_env_is_1
    ENV["KINDLING_DEBUG"] = "1"
    assert Kindling::Config.debug?
  end

  def test_debug_false_for_other_values
    ENV["KINDLING_DEBUG"] = "false"
    refute Kindling::Config.debug?

    ENV["KINDLING_DEBUG"] = "0"
    refute Kindling::Config.debug?

    ENV["KINDLING_DEBUG"] = "yes"
    refute Kindling::Config.debug?
  end

  def test_current_memory_mb_returns_numeric
    memory = Kindling::Config.current_memory_mb
    assert_kind_of Numeric, memory
    assert memory >= 0
  end

  def test_current_memory_mb_handles_error
    # Mock ps command failure
    Kindling::Config.stub :`, proc { raise "command failed" } do
      assert_equal 0, Kindling::Config.current_memory_mb
    end
  end

  def test_within_memory_limit_when_below
    # Mock low memory usage
    Kindling::Config.stub :current_memory_mb, 100 do
      assert Kindling::Config.within_memory_limit?
    end
  end

  def test_within_memory_limit_when_at_limit
    # Mock memory at limit
    Kindling::Config.stub :current_memory_mb, 2000 do
      assert Kindling::Config.within_memory_limit?
    end
  end

  def test_within_memory_limit_when_above
    # Mock high memory usage
    Kindling::Config.stub :current_memory_mb, 2100 do
      refute Kindling::Config.within_memory_limit?
    end
  end

  def test_log_memory_does_nothing_when_not_debug
    ENV.delete("KINDLING_DEBUG")

    # Should not call Logging.debug
    called = false
    Kindling::Logging.stub :debug, proc { called = true } do
      Kindling::Config.log_memory
    end
    refute called
  end

  def test_log_memory_logs_when_debug
    ENV["KINDLING_DEBUG"] = "true"

    logged_messages = []
    Kindling::Logging.stub :debug, proc { |msg| logged_messages << msg } do
      Kindling::Config.stub :current_memory_mb, 150 do
        Kindling::Config.log_memory
      end
    end

    assert_equal 1, logged_messages.size
    assert_match(/Memory usage.*150.*MB/, logged_messages.first)
  end

  def test_log_memory_with_context
    ENV["KINDLING_DEBUG"] = "true"

    logged_messages = []
    Kindling::Logging.stub :debug, proc { |msg| logged_messages << msg } do
      Kindling::Config.stub :current_memory_mb, 150 do
        Kindling::Config.log_memory("after indexing")
      end
    end

    assert_match(/Memory usage.*after indexing.*150.*MB/, logged_messages.first)
  end

  def test_log_memory_warns_when_over_limit
    ENV["KINDLING_DEBUG"] = "true"

    debug_messages = []
    warn_messages = []

    Kindling::Logging.stub :debug, proc { |msg| debug_messages << msg } do
      Kindling::Logging.stub :warn, proc { |msg| warn_messages << msg } do
        Kindling::Config.stub :current_memory_mb, 2100 do
          Kindling::Config.log_memory
        end
      end
    end

    assert_equal 1, debug_messages.size
    assert_equal 1, warn_messages.size
    assert_match(/Memory usage exceeds limit.*2100.*2000/, warn_messages.first)
  end

  def test_ps_command_format
    # Test that the ps command is properly formatted
    pid = Process.pid
    output = `ps -o rss= -p #{pid}`.strip

    # Should return a number (RSS in KB)
    assert_match(/^\d+$/, output)
    assert output.to_i > 0
  end

  def test_memory_conversion_to_mb
    # Mock ps output in KB
    Kindling::Config.stub :`, "102400" do
      # 102400 KB = 100 MB
      assert_equal 100.0, Kindling::Config.current_memory_mb
    end
  end

  def test_memory_rounding
    # Mock ps output that results in fractional MB
    Kindling::Config.stub :`, "102456" do
      # Should round to 2 decimal places
      memory = Kindling::Config.current_memory_mb
      assert_equal 100.05, memory
    end
  end

  def test_environment_variable_overrides
    # Test that environment variables can override defaults
    # Note: These are set at module load time, so we can't easily test runtime changes
    # But we can verify the current values respect ENV if set

    # Save current ENV values
    original_max_files = ENV["KINDLING_MAX_FILES"]

    # Since the constants are already loaded, we can only verify they use ENV.fetch
    # This test mainly documents the feature exists
    assert_kind_of Integer, Kindling::Config::MAX_FILES
    assert_kind_of Integer, Kindling::Config::MAX_MEMORY_MB
    assert_kind_of Integer, Kindling::Config::MAX_DIR_SIZE_MB

    # Restore original ENV
    if original_max_files
      ENV["KINDLING_MAX_FILES"] = original_max_files
    else
      ENV.delete("KINDLING_MAX_FILES")
    end
  end
end
