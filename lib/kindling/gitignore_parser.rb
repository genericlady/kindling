# frozen_string_literal: true

module Kindling
  # Parses and applies .gitignore patterns
  class GitignoreParser
    # Initialize with optional patterns
    def initialize(patterns = [])
      @patterns = []
      add_patterns(patterns) if patterns.any?
    end
    
    # Load patterns from a .gitignore file
    def load_file(path)
      return unless File.exist?(path)
      
      File.readlines(path).each do |line|
        line = line.strip
        # Skip empty lines and comments
        next if line.empty? || line.start_with?('#')
        
        add_pattern(line)
      end
    rescue => e
      Logging.debug("Failed to read .gitignore: #{e.message}")
    end
    
    # Add a single pattern
    def add_pattern(pattern)
      return if pattern.empty? || pattern.start_with?('#')
      
      # Parse the pattern into a rule
      rule = parse_pattern(pattern)
      @patterns << rule if rule
    end
    
    # Add multiple patterns
    def add_patterns(patterns)
      patterns.each { |p| add_pattern(p) }
    end
    
    # Check if a path should be ignored
    # @param path [String] Relative path from root
    # @param is_directory [Boolean] Whether the path is a directory
    def ignored?(path, is_directory: false)
      return false if @patterns.empty?
      
      # Check each pattern
      @patterns.any? do |rule|
        matches_pattern?(path, rule, is_directory)
      end
    end
    
    private
    
    # Parse a gitignore pattern into a rule
    def parse_pattern(pattern)
      original = pattern.dup
      negated = false
      directory_only = false
      anchored = false
      
      # Check for negation
      if pattern.start_with?('!')
        negated = true
        pattern = pattern[1..]
      end
      
      # Check for directory-only match
      if pattern.end_with?('/')
        directory_only = true
        pattern = pattern[0..-2]
      end
      
      # Check if pattern is anchored (starts with / or contains / in the middle)
      if pattern.start_with?('/')
        anchored = true
        pattern = pattern[1..] # Remove leading slash for matching
      else
        anchored = pattern.include?('/')
      end
      
      # Convert glob pattern to regex
      regex = glob_to_regex(pattern, anchored)
      
      {
        original: original,
        pattern: pattern,
        regex: regex,
        negated: negated,
        directory_only: directory_only,
        anchored: anchored
      }
    rescue => e
      Logging.debug("Invalid gitignore pattern '#{original}': #{e.message}")
      nil
    end
    
    # Convert a glob pattern to a regex
    def glob_to_regex(pattern, anchored)
      # Special case for patterns starting with **/
      if pattern.start_with?('**/')
        # This should match at any level including root
        pattern = pattern[3..] # Remove **/
        anchored = false # Make it unanchored to match anywhere
      end
      
      # Handle other double asterisks
      pattern = pattern.gsub('/**/', '/___DOUBLESTAR___/')
      pattern = pattern.gsub('/**', '/___DOUBLESTAR___')
      
      # Escape special regex characters except glob wildcards * and ? and []
      escaped = pattern
      escaped = escaped.gsub('.', '\.')
      escaped = escaped.gsub('+', '\+')
      escaped = escaped.gsub('^', '\^')
      escaped = escaped.gsub('$', '\$')
      escaped = escaped.gsub('{', '\{')
      escaped = escaped.gsub('}', '\}')
      escaped = escaped.gsub('(', '\(')
      escaped = escaped.gsub(')', '\)')
      escaped = escaped.gsub('|', '\|')
      # Don't escape [ and ] as they're used for character classes in gitignore
      
      # Replace glob wildcards
      # ** matches any number of directories
      escaped = escaped.gsub('___DOUBLESTAR___', '.*')
      # * matches any characters except /
      escaped = escaped.gsub('*', '[^/]*')
      # ? matches single character except /
      escaped = escaped.gsub('?', '[^/]')
      
      # Build the final regex
      if anchored
        # Anchored patterns match from the beginning
        Regexp.new("^#{escaped}(/.*)?$")
      else
        # Unanchored patterns can match anywhere
        Regexp.new("(^|.*/)#{escaped}(/.*)?$")
      end
    end
    
    # Check if a path matches a pattern rule
    def matches_pattern?(path, rule, is_directory)
      # Directory-only patterns don't match files
      return false if rule[:directory_only] && !is_directory
      
      # Test the regex against the path
      matches = rule[:regex].match?(path)
      
      # Handle negation
      rule[:negated] ? !matches : matches
    end
  end
end