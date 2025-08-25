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
      ".cache",
      ".idea",           # IntelliJ
      ".vscode",         # VS Code
      "target",          # Maven/Gradle
      ".gradle",         # Gradle
      ".mvn",            # Maven
      "out",             # Build output
      ".next",           # Next.js
      ".nuxt",           # Nuxt.js
      "bower_components", # Bower
      ".terraform",      # Terraform
      "__pycache__",     # Python
      ".pytest_cache",   # Python pytest
      ".tox",            # Python tox
      "*.pyc",           # Python compiled
      ".sass-cache",     # Sass
      ".parcel-cache"    # Parcel
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
      skipped_dirs = 0
      start_time = Time.now

      Logging.info("Starting indexing of #{root}")
      limit_msg = (Config::MAX_FILES > 0) ? "#{Config::MAX_FILES} files" : "unlimited"
      dir_limit_msg = (Config::MAX_DIR_FILE_COUNT > 0) ? Config::MAX_DIR_FILE_COUNT.to_s : "unlimited"
      Logging.info("Limits: #{limit_msg}, Max dir files: #{dir_limit_msg}")

      # Load .gitignore if it exists and we're using it
      if @use_gitignore
        @gitignore_parser = GitignoreParser.new
        gitignore_path = File.join(root, ".gitignore")
        @gitignore_parser.load_file(gitignore_path) if File.exist?(gitignore_path)
      end

      Find.find(root) do |path|
        # Check cancellation every iteration
        if @cancel
          Logging.info("Indexing cancelled after #{count} files")
          Find.prune
          break
        end

        # Stop if we hit the max file limit (only if limit is set)
        if Config::MAX_FILES > 0 && count >= Config::MAX_FILES
          Logging.warn("Hit maximum file limit (#{Config::MAX_FILES}), stopping indexing")
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
          if pathname.directory?
            skipped_dirs += 1
            Logging.debug("Skipping ignored directory: #{basename}")
          end
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
          skipped_dirs += 1
          Logging.info("Skipping large directory: #{relative}")
          Find.prune
          next
        end

        # Only track files, not directories
        if pathname.file?
          @paths << relative
          count += 1

          # Report progress with better intervals for large repos
          if count % Config::PROGRESS_UPDATE_INTERVAL == 0 && on_progress
            elapsed = Time.now - start_time
            rate = (count / elapsed).round(0)
            Logging.debug("Indexed #{count} files (#{rate} files/sec)")
            on_progress.call(count)
          end
        end
      end

      # Final statistics
      elapsed = Time.now - start_time
      Logging.info("Indexing complete: #{count} files found in #{elapsed.round(1)}s")
      Logging.info("Skipped #{skipped_dirs} directories") if skipped_dirs > 0

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
      # Skip check entirely if limits are disabled (0 = no limit)
      return false if Config::MAX_DIR_FILE_COUNT == 0 && Config::MAX_DIR_SIZE_MB == 0

      # Quick heuristic: check file count first (faster)
      file_count = 0
      total_size = 0

      begin
        Dir.foreach(dir_path) do |entry|
          next if entry == "." || entry == ".."

          file_count += 1
          # Stop counting if we exceed the limit (only if limit is set)
          if Config::MAX_DIR_FILE_COUNT > 0 && file_count > Config::MAX_DIR_FILE_COUNT
            return true
          end

          # Check size for a sample of files (checking all would be slow)
          if Config::MAX_DIR_SIZE_MB > 0 && file_count <= 100
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
