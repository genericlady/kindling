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
    
    # Score a single path against query
    def score_path(path, query_chars, query_lower)
      path_lower = path.downcase
      basename_lower = File.basename(path).downcase
      
      # Quick reject if query not present as subsequence
      return 0 unless subsequence_match?(path_lower, query_chars)
      
      score = 0
      query_idx = 0
      last_match_idx = -1
      in_basename = false
      
      path_lower.chars.each_with_index do |char, idx|
        # Track if we're in the basename
        in_basename = true if idx >= (path.length - basename_lower.length)
        
        if query_idx < query_chars.length && char == query_chars[query_idx]
          # Base match score
          score += MATCH_BONUS
          
          # Consecutive match bonus
          score += CONSECUTIVE_BONUS if last_match_idx == idx - 1
          
          # Start of string/word bonus
          if idx == 0 || SEPARATORS.include?(path[idx - 1])
            score += START_BONUS
          end
          
          # After separator bonus
          if idx > 0 && SEPARATORS.include?(path[idx - 1])
            score += SEPARATOR_BONUS
            # Extra bonus for path separators
            score += PATH_SEPARATOR_BONUS if path[idx - 1] == PATH_SEPARATOR
          end
          
          # Basename bonus
          score += BASENAME_BONUS if in_basename
          
          last_match_idx = idx
          query_idx += 1
        end
      end
      
      # Only return score if all query chars were matched
      query_idx == query_chars.length ? score : 0
    end
    
    # Check if query exists as subsequence in text
    def subsequence_match?(text, query_chars)
      query_idx = 0
      text.each_char do |char|
        if query_idx < query_chars.length && char == query_chars[query_idx]
          query_idx += 1
        end
      end
      query_idx == query_chars.length
    end
  end
end