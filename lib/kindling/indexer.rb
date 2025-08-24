# frozen_string_literal: true

module Kindling
  # Recursive file indexer with cancellation support and ignore rules
  class Indexer
    # Default patterns to ignore
    DEFAULT_IGNORES = [
      ".git",
      "node_modules", 
      ".DS_Store",
      "tmp",
      "log",
      ".bundle",
      "vendor/bundle",
      "coverage",
      "build",
      "dist",
      ".cache"
    ].freeze
    
    def initialize(ignores: DEFAULT_IGNORES)
      @ignores = ignores
      @cancel = false
      @paths = []
    end
    
    # Index all files under root path
    # @param root [String] Root directory to index
    # @param on_progress [Proc] Called periodically with file count
    # @yield [Array<String>] Called on completion with all relative paths
    def index(root, on_progress: nil)
      @cancel = false
      @paths = []
      @root = Pathname.new(root)
      count = 0
      
      Find.find(root) do |path|
        # Check cancellation every iteration
        if @cancel
          Find.prune
          break
        end
        
        pathname = Pathname.new(path)
        basename = pathname.basename.to_s
        
        # Skip ignored patterns
        if should_ignore?(basename)
          Find.prune if pathname.directory?
          next
        end
        
        # Only track files, not directories
        if pathname.file?
          begin
            relative = pathname.relative_path_from(@root).to_s
            @paths << relative
            count += 1
            
            # Report progress every 200 files
            if count % 200 == 0 && on_progress
              on_progress.call(count)
            end
          rescue => e
            Logging.debug("Skipped unreadable file: #{path} - #{e.message}")
          end
        end
      end
      
      # Final progress update
      on_progress&.call(count)
      
      # Return paths on completion
      yield @paths if block_given?
      @paths
    end
    
    # Cancel ongoing indexing operation
    def cancel!
      @cancel = true
    end
    
    private
    
    def should_ignore?(name)
      @ignores.any? { |pattern| name == pattern || name.start_with?(".#{pattern}") }
    end
  end
end