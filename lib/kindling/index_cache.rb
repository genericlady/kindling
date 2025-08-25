# frozen_string_literal: true

require "json"
require "tmpdir"
require "digest"

module Kindling
  class IndexCache
    def initialize(root)
      @root = File.expand_path(root)
      @path = File.join(Dir.tmpdir, "kindling_index_#{fingerprint}.json")
    end

    def load
      return {"files" => [], "mtimes" => {}} unless File.exist?(@path)
      JSON.parse(File.read(@path))
    rescue => e
      Logging.debug("IndexCache load failed: #{e.message}")
      {"files" => [], "mtimes" => {}}
    end

    def save(files:, mtimes:)
      tmp = "#{@path}.tmp"
      File.write(tmp, JSON.dump({"files" => files, "mtimes" => mtimes}))
      File.rename(tmp, @path)
    rescue => e
      Logging.debug("IndexCache save failed: #{e.message}")
    end

    def clear
      File.delete(@path) if File.exist?(@path)
    rescue => e
      Logging.debug("IndexCache clear failed: #{e.message}")
    end

    private

    def fingerprint
      Digest::SHA256.hexdigest(@root)[0, 16]
    end
  end
end
