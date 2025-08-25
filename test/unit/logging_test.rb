# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"

class LoggingTest < Minitest::Test
  def setup
    # Reset logger state before each test
    Kindling::Logging.instance_variable_set(:@logger, nil)
    Kindling::Logging.instance_variable_set(:@debug_enabled, false)

    # Capture stdout for testing
    @original_stdout = $stdout
    @output = StringIO.new
    $stdout = @output
  end

  def teardown
    # Restore stdout
    $stdout = @original_stdout
  end

  def test_debug_disabled_by_default
    refute Kindling::Logging.debug?
  end

  def test_enable_debug
    Kindling::Logging.enable_debug!
    assert Kindling::Logging.debug?
  end

  def test_disable_debug
    Kindling::Logging.enable_debug!
    Kindling::Logging.disable_debug!
    refute Kindling::Logging.debug?
  end

  def test_debug_message_not_logged_when_disabled
    Kindling::Logging.debug("test debug message")
    assert_empty @output.string
  end

  def test_debug_message_logged_when_enabled
    Kindling::Logging.enable_debug!
    Kindling::Logging.debug("test debug message")
    assert_match(/DEBUG.*test debug message/, @output.string)
  end

  def test_debug_with_context
    Kindling::Logging.enable_debug!
    Kindling::Logging.debug("test", file: "example.rb", line: 42)
    output = @output.string
    assert_match(/test.*file="example.rb".*line=42/, output)
  end

  def test_info_message
    Kindling::Logging.info("test info message")
    assert_match(/INFO.*test info message/, @output.string)
  end

  def test_info_with_context
    Kindling::Logging.info("processing", files: 100, elapsed: 1.5)
    output = @output.string
    assert_match(/processing.*files=100.*elapsed=1.5/, output)
  end

  def test_warn_message
    Kindling::Logging.warn("test warning")
    assert_match(/WARN.*test warning/, @output.string)
  end

  def test_warn_with_context
    Kindling::Logging.warn("memory high", usage_mb: 250, limit_mb: 200)
    output = @output.string
    assert_match(/memory high.*usage_mb=250.*limit_mb=200/, output)
  end

  def test_error_message
    Kindling::Logging.error("test error")
    assert_match(/ERROR.*test error/, @output.string)
  end

  def test_error_with_context
    Kindling::Logging.error("connection failed", host: "localhost", port: 3000)
    output = @output.string
    assert_match(/connection failed.*host="localhost".*port=3000/, output)
  end

  def test_benchmark_when_debug_disabled
    result = Kindling::Logging.benchmark("operation") { "result" }
    assert_equal "result", result
    assert_empty @output.string
  end

  def test_benchmark_when_debug_enabled
    Kindling::Logging.enable_debug!
    result = Kindling::Logging.benchmark("slow operation") do
      sleep 0.01
      "done"
    end

    assert_equal "done", result
    output = @output.string
    assert_match(/slow operation:.*\d+\.\d+ms/, output)
  end

  def test_benchmark_preserves_return_value
    Kindling::Logging.enable_debug!
    result = Kindling::Logging.benchmark("calculation") { 2 + 2 }
    assert_equal 4, result
  end

  def test_log_format_includes_timestamp
    Kindling::Logging.info("test")
    output = @output.string
    # Check for timestamp format HH:MM:SS.mmm
    assert_match(/\[\d{2}:\d{2}:\d{2}\.\d{3}\]/, output)
  end

  def test_log_format_includes_severity
    Kindling::Logging.info("test")
    assert_match(/INFO/, @output.string)

    @output.truncate(0)
    Kindling::Logging.warn("test")
    assert_match(/WARN/, @output.string)
  end

  def test_empty_context_not_shown
    Kindling::Logging.info("message")
    refute_match(/\[.*\]/, @output.string.gsub(/\[\d{2}:\d{2}:\d{2}\.\d{3}\]/, ""))
  end

  def test_multiple_context_values
    Kindling::Logging.info("event", a: 1, b: "two", c: :three)
    output = @output.string
    assert_match(/a=1/, output)
    assert_match(/b="two"/, output)
    assert_match(/c=:three/, output)
  end

  def test_benchmark_with_exception
    Kindling::Logging.enable_debug!
    assert_raises(RuntimeError) do
      Kindling::Logging.benchmark("failing operation") do
        raise "test error"
      end
    end
  end

  def test_thread_safety
    # Test that logging from multiple threads doesn't crash
    threads = 5.times.map do |i|
      Thread.new do
        10.times do |j|
          Kindling::Logging.info("thread #{i} message #{j}")
        end
      end
    end

    threads.each(&:join)
    output_lines = @output.string.lines
    assert_equal 50, output_lines.size
  end
end
