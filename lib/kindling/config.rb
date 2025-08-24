# frozen_string_literal: true

module Kindling
  # Configuration for performance tuning and behavior
  module Config
    extend self
    
    # Performance settings
    MAX_FILES = 250_000
    MAX_VISIBLE_RESULTS = 5_000
    MAX_PREVIEW_PATHS = 1_000
    DEBOUNCE_MS = 200
    PROGRESS_UPDATE_INTERVAL = 200 # files
    
    # Memory limits
    MAX_MEMORY_MB = 250
    
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
      Logging.debug("Memory usage#{context.empty? ? '' : " (#{context})"}: #{mb} MB")
      
      if mb > MAX_MEMORY_MB
        Logging.warn("Memory usage exceeds limit: #{mb} MB > #{MAX_MEMORY_MB} MB")
      end
    end
  end
end