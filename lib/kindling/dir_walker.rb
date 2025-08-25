# frozen_string_literal: true

require "pathname"

module Kindling
  class DirWalker
    DEFAULT_QUEUE_SIZE = 10_000
    class Cancelled < StandardError; end

    def initialize(root:, ignores:, gitignore_parser:, max_dir_entries:, max_dir_sample_mb:, cancel_token:, queue_size: DEFAULT_QUEUE_SIZE)
      @root = Pathname.new(root)
      @ignores = ignores
      @gitignore = gitignore_parser
      @max_entries = max_dir_entries
      @max_sample_bytes = max_dir_sample_mb * 1_048_576
      @cancel = cancel_token
      @queue = SizedQueue.new(queue_size)
    end

    attr_reader :queue

    def start!
      @thread = Thread.new { walk }
      self
    end

    def join
      @thread&.join
    end

    private

    def walk
      stack = [@root]
      until stack.empty?
        raise Cancelled if @cancel.cancelled?

        dir = stack.pop
        entries = begin
          Dir.children(dir)
        rescue
          next
        end

        if too_big?(dir, entries)
          Logging.debug("Pruned large dir: #{rel(dir)}")
          next
        end

        entries.each do |name|
          raise Cancelled if @cancel.cancelled?

          path = dir.join(name)
          relp = rel(path)
          base = path.basename.to_s

          next if hard_ignored?(base) || @gitignore&.ignored?(relp, is_directory: path.directory?)

          if path.directory?
            stack << path
          else
            @queue.push(relp)
          end
        end
      end
    rescue Cancelled
      Logging.debug("DirWalker cancelled")
    ensure
      @queue.push(nil) # End-of-stream sentinel
    end

    def hard_ignored?(name)
      @ignores.any? { |pat| name == pat || name.start_with?(".#{pat}") }
    end

    def rel(path)
      path.relative_path_from(@root).to_s
    end

    def too_big?(dir, entries)
      return false if @max_entries <= 0 && @max_sample_bytes <= 0
      return true if @max_entries > 0 && entries.size > @max_entries
      return false if @max_sample_bytes <= 0

      size = 0
      entries.first(100).each do |e|
        f = dir.join(e)
        next unless f.file?
        size += f.size
        return true if size > @max_sample_bytes
      end
      false
    end
  end
end
