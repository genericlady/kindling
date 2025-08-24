# frozen_string_literal: true

module Kindling
  # Tracks selected file paths
  class Selection
    include Enumerable
    
    def initialize
      @paths = Set.new
    end
    
    # Add a path to selection
    def add(path)
      @paths.add(path)
    end
    
    # Remove a path from selection
    def remove(path)
      @paths.delete(path)
    end
    
    # Toggle path selection
    def toggle(path)
      if @paths.include?(path)
        remove(path)
      else
        add(path)
      end
    end
    
    # Replace all selections
    def replace(paths)
      @paths = Set.new(paths)
    end
    
    # Clear all selections
    def clear
      @paths.clear
    end
    
    # Check if path is selected
    def include?(path)
      @paths.include?(path)
    end
    
    # Get count of selected paths
    def size
      @paths.size
    end
    alias_method :count, :size
    
    # Check if any paths selected
    def any?
      @paths.any?
    end
    
    # Check if no paths selected
    def empty?
      @paths.empty?
    end
    
    # Iterate over selected paths
    def each(&block)
      @paths.each(&block)
    end
    
    # Convert to array (sorted)
    def to_a
      @paths.to_a.sort
    end
  end
end