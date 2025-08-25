# frozen_string_literal: true

module Kindling
  # Configuration for performance tuning and behavior
  module Config
    extend self

    # Performance settings (can be overridden with environment variables)
    # File limits - set to 0 for unlimited
    MAX_FILES = ENV.fetch("KINDLING_MAX_FILES", "0").to_i  # 0 = unlimited (default for enterprise)

    # UI performance limits (these stay to prevent UI lag)
    MAX_VISIBLE_RESULTS = ENV.fetch("KINDLING_MAX_VISIBLE", "5000").to_i
    MAX_PREVIEW_PATHS = ENV.fetch("KINDLING_MAX_PREVIEW", "1000").to_i
    DEBOUNCE_MS = ENV.fetch("KINDLING_DEBOUNCE_MS", "200").to_i
    PROGRESS_UPDATE_INTERVAL = ENV.fetch("KINDLING_PROGRESS_INTERVAL", "1000").to_i  # Every 1000 files

    # Directory size checks - set to 0 to disable
    # These are kept as safety checks but can be disabled
    MAX_DIR_SIZE_MB = ENV.fetch("KINDLING_MAX_DIR_SIZE_MB", "0").to_i  # 0 = no limit
    MAX_DIR_FILE_COUNT = ENV.fetch("KINDLING_MAX_DIR_FILES", "0").to_i  # 0 = no limit

    # Memory limits - still useful to prevent runaway memory usage
    MAX_MEMORY_MB = ENV.fetch("KINDLING_MAX_MEMORY_MB", "2000").to_i  # 2GB default

    # UI settings
    WINDOW_WIDTH = 1200
    WINDOW_HEIGHT = 800
    PANE_POSITION = 0.6 # 60% for file list, 40% for preview

    # Search settings
    MIN_QUERY_LENGTH = 1
    PREFIX_SEARCH_THRESHOLD = 2 # Use prefix search for queries shorter than this

    # File patterns to ignore (in addition to Indexer defaults)
    ADDITIONAL_IGNORES = []

    # Get all ignore patterns
    def ignore_patterns
      Indexer::DEFAULT_IGNORES + ADDITIONAL_IGNORES
    end

    # Check if we're in debug mode
    def debug?
      ENV["KINDLING_DEBUG"] == "true" || ENV["KINDLING_DEBUG"] == "1"
    end

    # Get memory usage in MB
    def current_memory_mb
      # Use ps to get RSS in KB, convert to MB
      pid = Process.pid
      output = `ps -o rss= -p #{pid}`.strip
      (output.to_i / 1024.0).round(2)
    rescue
      0
    end

    # Check if memory usage is within limits
    def within_memory_limit?
      current_memory_mb <= MAX_MEMORY_MB
    end

    # Log memory usage
    def log_memory(context = "")
      return unless debug?

      mb = current_memory_mb
      Logging.debug("Memory usage#{context.empty? ? "" : " (#{context})"}: #{mb} MB")

      if mb > MAX_MEMORY_MB
        Logging.warn("Memory usage exceeds limit: #{mb} MB > #{MAX_MEMORY_MB} MB")
      end
    end
  end
end
