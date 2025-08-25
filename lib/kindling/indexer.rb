# frozen_string_literal: true

require "pathname"
require_relative "gitignore_parser"
require_relative "index_cache"
require_relative "index_backends"
require_relative "dir_walker"
require_relative "cancellation_token"

module Kindling
  class Indexer
    DEFAULT_IGNORES = [
      ".git", "node_modules", ".DS_Store", "tmp", "log", ".bundle", "vendor",
      "coverage", "build", "dist", ".cache", ".idea", ".vscode", "target", ".gradle",
      ".mvn", "out", ".next", ".nuxt", "bower_components", ".terraform", "__pycache__",
      ".pytest_cache", ".tox", "*.pyc", ".sass-cache", ".parcel-cache"
    ].freeze

    def initialize(ignores: DEFAULT_IGNORES, use_gitignore: true)
      @ignores = ignores
      @use_gitignore = use_gitignore
      @cancel = CancellationToken.new
    end

    # Streams batches via yield, returns full array at end.
    def index(root, on_progress: nil, batch_size: Config::BATCH_SIZE)
      start = Time.now
      root = File.expand_path(root)
      Logging.info("Index start #{root}")

      gitignore = nil
      if @use_gitignore
        gi = File.join(root, ".gitignore")
        gitignore = GitignoreParser.new
        gitignore.load_file(gi) if File.exist?(gi)
      end

      all = []
      count = 0

      # 1) Try Rust backends (fd > rg) if enabled
      backend = select_backend
      if backend
        each_rel = (backend == :fd) ? IndexBackends.run_fd(root, respect_gitignore: @use_gitignore) : IndexBackends.run_rg(root, respect_gitignore: @use_gitignore)
        if each_rel
          batch = []
          each_rel.each do |rel|
            break if @cancel.cancelled?
            all << rel
            batch << rel
            count += 1
            if Config::MAX_FILES > 0 && count >= Config::MAX_FILES
              Logging.warn("Hit MAX_FILES=#{Config::MAX_FILES}")
              break
            end
            if batch.size >= batch_size
              on_progress&.call(count)
              yield batch if block_given?
              batch.clear
            end
          end
          unless batch.empty?
            on_progress&.call(count)
            yield batch if block_given?
          end
          finalize_cache(root, all)
          Logging.info("Index done via #{backend} in #{(Time.now - start).round(2)}s (#{count} files)")
          return all
        end
      end

      # 2) Fallback to internal walker with backpressure
      Logging.info("Using Ruby walker (backend: #{backend || "none available"})")
      walker = DirWalker.new(
        root: root,
        ignores: @ignores,
        gitignore_parser: gitignore,
        max_dir_entries: Config::MAX_DIR_FILE_COUNT,
        max_dir_sample_mb: Config::MAX_DIR_SIZE_MB,
        cancel_token: @cancel,
        queue_size: Config::WALK_QUEUE_SIZE
      ).start!

      batch = []
      while (rel = walker.queue.pop)
        break if @cancel.cancelled?
        all << rel
        batch << rel
        count += 1
        if Config::MAX_FILES > 0 && count >= Config::MAX_FILES
          Logging.warn("Hit MAX_FILES=#{Config::MAX_FILES}")
          @cancel.cancel! # Stop the walker
          break
        end
        if batch.size >= batch_size
          on_progress&.call(count)
          yield batch if block_given?
          batch.clear
        end
      end

      walker.join # Wait for walker thread to finish

      on_progress&.call(count)
      yield batch if block_given? && !batch.empty?

      finalize_cache(root, all)
      Logging.info("Index done via ruby walker in #{(Time.now - start).round(2)}s (#{count} files)")
      all
    end

    def cancel!
      @cancel.cancel!
    end

    private

    def select_backend
      case Config::INDEX_BACKEND
      when :fd then IndexBackends.find_fd ? :fd : nil
      when :rg then IndexBackends.find_rg ? :rg : nil
      when :none then nil
      else
        # :auto - prefer fd, fall back to rg
        if IndexBackends.find_fd
          :fd
        else
          (IndexBackends.find_rg ? :rg : nil)
        end
      end
    end

    def finalize_cache(root, files)
      # Cheap snapshot now; mtimes can be filled lazily as needed
      mtimes = {}
      files.first(5_000).each do |rel| # Cap stats cost
        fp = File.join(root, rel)
        begin
          mtimes[rel] = File.mtime(fp).to_i if File.file?(fp)
        rescue
          # Ignore stat errors
        end
      end
      IndexCache.new(root).save(files: files, mtimes: mtimes)
    rescue => e
      Logging.debug("Failed to save index cache: #{e.message}")
    end
  end
end
