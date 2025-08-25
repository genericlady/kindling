# frozen_string_literal: true

require "find"
require "pathname"

module Kindling
  # Recursive file indexer with cancellation support and ignore rules
  class Indexer
    # Default patterns to ignore (basic hardcoded patterns)
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

    def initialize(ignores: DEFAULT_IGNORES, use_gitignore: true)
      @ignores = ignores
      @use_gitignore = use_gitignore
      @cancel = false
      @paths = []
      @gitignore_parser = nil
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

      # Load .gitignore if it exists and we're using it
      if @use_gitignore
        @gitignore_parser = GitignoreParser.new
        gitignore_path = File.join(root, ".gitignore")
        @gitignore_parser.load_file(gitignore_path) if File.exist?(gitignore_path)
      end

      Find.find(root) do |path|
        # Check cancellation every iteration
        if @cancel
          Find.prune
          break
        end

        pathname = Pathname.new(path)
        basename = pathname.basename.to_s

        # Get relative path for gitignore checking
        begin
          relative = pathname.relative_path_from(@root).to_s
        rescue => e
          Logging.debug("Skipped unreadable path: #{path} - #{e.message}")
          next
        end

        # Skip ignored patterns (hardcoded)
        if should_ignore?(basename)
          Find.prune if pathname.directory?
          next
        end

        # Check gitignore patterns
        if @gitignore_parser&.ignored?(relative, is_directory: pathname.directory?)
          Find.prune if pathname.directory?
          next
        end

        # Check directory size limits
        if pathname.directory? && should_skip_large_directory?(pathname)
          Logging.debug("Skipping large directory: #{relative}")
          Find.prune
          next
        end

        # Only track files, not directories
        if pathname.file?
          @paths << relative
          count += 1

          # Report progress every 200 files
          if count % Config::PROGRESS_UPDATE_INTERVAL == 0 && on_progress
            on_progress.call(count)
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

    # Check if a directory should be skipped due to size limits
    def should_skip_large_directory?(dir_path)
      # Quick heuristic: check file count first (faster)
      file_count = 0
      total_size = 0

      begin
        Dir.foreach(dir_path) do |entry|
          next if entry == "." || entry == ".."

          file_count += 1
          # Stop counting if we exceed the limit
          return true if file_count > Config::MAX_DIR_FILE_COUNT

          # Check size for a sample of files (checking all would be slow)
          if file_count <= 100
            entry_path = File.join(dir_path, entry)
            if File.file?(entry_path)
              total_size += File.size(entry_path)
              # Convert to MB and check
              return true if total_size > Config::MAX_DIR_SIZE_MB * 1_048_576
            end
          end
        end
      rescue => e
        Logging.debug("Error checking directory size for #{dir_path}: #{e.message}")
      end

      false
    end
  end
end
