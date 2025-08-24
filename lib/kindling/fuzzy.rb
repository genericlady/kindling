# frozen_string_literal: true

module Kindling
  # Fast fuzzy search implementation with subsequence matching and scoring
  module Fuzzy
    extend self

    # Score bonuses
    MATCH_BONUS = 5
    CONSECUTIVE_BONUS = 3
    START_BONUS = 2
    SEPARATOR_BONUS = 2
    PATH_SEPARATOR_BONUS = 5  # Extra bonus for path separators
    BASENAME_BONUS = 10

    # Separators that get bonus points
    SEPARATORS = %w[/ _ - .].freeze
    PATH_SEPARATOR = "/"

    # Filter paths by fuzzy matching query
    # @param paths [Array<String>] List of relative paths
    # @param query [String] Search query
    # @param limit [Integer] Maximum results to return
    # @return [Array<String>] Filtered and sorted paths
    def filter(paths, query, limit: 5_000)
      return paths.first(limit) if query.nil? || query.empty?

      query_lower = query.downcase
      query_chars = query_lower.chars

      # Fast path for very short queries
      if query.length < 2
        return prefix_filter(paths, query_lower, limit)
      end

      start_time = Time.now if ENV["KINDLING_DEBUG"]

      # Score all matching paths
      results = []
      paths.each do |path|
        score = score_path(path, query_chars, query_lower)
        results << [path, score] if score > 0
      end

      # Sort by score descending, then by path length (shorter wins)
      results.sort! do |a, b|
        score_cmp = b[1] <=> a[1]
        score_cmp.zero? ? a[0].length <=> b[0].length : score_cmp
      end

      # Take top N results
      filtered = results.first(limit).map(&:first)

      if ENV["KINDLING_DEBUG"]
        elapsed = ((Time.now - start_time) * 1000).round(2)
        Logging.debug("Fuzzy filter: #{paths.size} paths -> #{results.size} matches -> #{filtered.size} results in #{elapsed}ms")
      end

      filtered
    end

    private

    # Fast prefix matching for short queries
    def prefix_filter(paths, query, limit)
      paths.select { |p|
        basename = File.basename(p).downcase
        basename.start_with?(query) || p.downcase.include?(query)
      }.first(limit)
    end

    # Score a single path against query (combined matching and scoring for efficiency)
    def score_path(path, query_chars, query_lower)
      # Early exit for paths shorter than query
      return 0 if path.length < query_chars.length
      
      path_lower = path.downcase
      basename_lower = File.basename(path).downcase
      basename_start = path.length - basename_lower.length

      score = 0
      query_idx = 0
      last_match_idx = -1

      # Single pass for both matching and scoring
      path_lower.each_char.with_index do |char, idx|
        # Skip if we've matched all query chars
        break if query_idx >= query_chars.length

        if char == query_chars[query_idx]
          # Base match score
          score += MATCH_BONUS

          # Consecutive match bonus
          score += CONSECUTIVE_BONUS if last_match_idx == idx - 1

          # Start of string/word bonus
          if idx == 0 || (idx > 0 && SEPARATORS.include?(path[idx - 1]))
            score += START_BONUS
            
            # After separator bonus (combined with above check)
            if idx > 0
              score += SEPARATOR_BONUS
              # Extra bonus for path separators
              score += PATH_SEPARATOR_BONUS if path[idx - 1] == PATH_SEPARATOR
            end
          end

          # Basename bonus
          score += BASENAME_BONUS if idx >= basename_start

          last_match_idx = idx
          query_idx += 1
        end
      end

      # Only return score if all query chars were matched
      (query_idx == query_chars.length) ? score : 0
    end
  end
end
