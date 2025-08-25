# frozen_string_literal: true

module Kindling
  class CancellationToken
    def initialize
      @mutex = Mutex.new
      @cancelled = false
    end

    def cancel!
      @mutex.synchronize { @cancelled = true }
    end

    def cancelled?
      @mutex.synchronize { @cancelled }
    end
  end
end
