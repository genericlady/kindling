# frozen_string_literal: true

require_relative "../test_helper"

class CancellationTokenTest < Minitest::Test
  def setup
    @token = Kindling::CancellationToken.new
  end

  def test_initial_state_not_cancelled
    refute @token.cancelled?
  end

  def test_cancel_sets_cancelled_state
    @token.cancel!
    assert @token.cancelled?
  end

  def test_cancel_is_idempotent
    @token.cancel!
    assert @token.cancelled?

    # Calling again should not raise
    @token.cancel!
    assert @token.cancelled?
  end

  def test_thread_safety
    results = []
    threads = []

    # Create multiple threads trying to cancel
    10.times do
      threads << Thread.new do
        @token.cancel!
        results << @token.cancelled?
      end
    end

    threads.each(&:join)

    # All threads should see cancelled state
    assert results.all?
    assert_equal 10, results.size
  end

  def test_multiple_tokens_are_independent
    token1 = Kindling::CancellationToken.new
    token2 = Kindling::CancellationToken.new

    token1.cancel!

    assert token1.cancelled?
    refute token2.cancelled?
  end

  def test_usage_in_loop
    token = Kindling::CancellationToken.new
    counter = 0

    # Simulate a loop that checks cancellation
    thread = Thread.new do
      until token.cancelled?
        counter += 1
        sleep 0.01
      end
    end

    # Let it run a bit
    sleep 0.05

    # Cancel and wait
    token.cancel!
    thread.join(1) # Wait up to 1 second

    # Counter should have incremented but then stopped
    assert counter > 0
    assert token.cancelled?
  end
end
