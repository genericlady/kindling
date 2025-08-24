# frozen_string_literal: true

require "logger"

module Kindling
  # Structured logging with debug toggle
  module Logging
    extend self

    @debug_enabled = false
    @logger = nil

    # Enable debug logging
    def enable_debug!
      @debug_enabled = true
      logger.level = Logger::DEBUG
    end

    # Disable debug logging
    def disable_debug!
      @debug_enabled = false
      logger.level = Logger::INFO
    end

    # Check if debug is enabled
    def debug?
      @debug_enabled
    end

    # Log debug message
    def debug(message, **context)
      return unless @debug_enabled
      logger.debug(format_message(message, context))
    end

    # Log info message
    def info(message, **context)
      logger.info(format_message(message, context))
    end

    # Log warning message
    def warn(message, **context)
      logger.warn(format_message(message, context))
    end

    # Log error message
    def error(message, **context)
      logger.error(format_message(message, context))
    end

    # Benchmark and log execution time
    def benchmark(label, &block)
      return yield unless @debug_enabled

      start = Time.now
      result = yield
      elapsed = ((Time.now - start) * 1000).round(2)

      debug("#{label}: #{elapsed}ms")
      result
    end

    private

    def logger
      @logger ||= create_logger
    end

    def create_logger
      log = Logger.new($stdout)
      log.level = @debug_enabled ? Logger::DEBUG : Logger::INFO

      # Simple format: timestamp level message
      log.formatter = proc do |severity, datetime, _progname, msg|
        timestamp = datetime.strftime("%H:%M:%S.%L")
        "[#{timestamp}] #{severity.ljust(5)} #{msg}\n"
      end

      log
    end

    def format_message(message, context)
      return message if context.empty?

      context_str = context.map { |k, v| "#{k}=#{v.inspect}" }.join(" ")
      "#{message} [#{context_str}]"
    end
  end
end
