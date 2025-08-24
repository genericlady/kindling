# frozen_string_literal: true

module Kindling
  # Renders selected paths as ASCII tree with Unicode box characters
  module TreeRenderer
    extend self
    
    # Unicode box drawing characters
    BRANCH = "├── "
    LAST_BRANCH = "└── "
    VERTICAL = "│   "
    EMPTY = "    "
    
    # Render paths as ASCII tree
    # @param paths [Array<String>] Sorted list of relative paths
    # @param root_name [String] Optional root folder name to display
    # @return [String] ASCII tree representation
    def render(paths, root_name: nil)
      return "" if paths.empty?
      
      # Build nested hash structure
      tree = build_tree(paths)
      
      # Render to string
      lines = []
      
      # Add root folder name if provided
      if root_name
        lines << "#{root_name}/"
      elsif paths.any?
        # Try to infer root from paths
        common_root = find_common_root(paths)
        lines << "#{common_root}/" if common_root
      end
      
      # Render tree structure
      render_node(tree, lines, "")
      
      lines.join("\n")
    end
    
    private
    
    # Build nested hash tree from flat paths
    def build_tree(paths)
      tree = {}
      
      paths.each do |path|
        parts = path.split("/")
        current = tree
        
        parts.each_with_index do |part, idx|
          if idx == parts.length - 1
            # Leaf node (file)
            current[part] = true
          else
            # Directory node
            current[part] ||= {}
            current = current[part]
          end
        end
      end
      
      tree
    end
    
    # Recursively render tree node
    def render_node(node, lines, prefix)
      return unless node.is_a?(Hash)
      
      # Sort entries: directories first, then files, alphabetically
      entries = node.keys.sort do |a, b|
        a_is_dir = node[a].is_a?(Hash)
        b_is_dir = node[b].is_a?(Hash)
        
        if a_is_dir && !b_is_dir
          -1
        elsif !a_is_dir && b_is_dir
          1
        else
          a <=> b
        end
      end
      
      entries.each_with_index do |name, idx|
        is_last = idx == entries.length - 1
        value = node[name]
        
        # Choose branch character
        branch = is_last ? LAST_BRANCH : BRANCH
        
        # Add line
        if value.is_a?(Hash)
          # Directory
          lines << "#{prefix}#{branch}#{name}/"
          
          # Recurse with updated prefix
          new_prefix = prefix + (is_last ? EMPTY : VERTICAL)
          render_node(value, lines, new_prefix)
        else
          # File
          lines << "#{prefix}#{branch}#{name}"
        end
      end
    end
    
    # Find common root directory from paths
    def find_common_root(paths)
      return nil if paths.empty?
      
      # Get first path's directory parts
      first_parts = paths.first.split("/")[0...-1]
      return nil if first_parts.empty?
      
      # Find how many parts are common to all paths
      common_depth = first_parts.length
      
      paths.each do |path|
        parts = path.split("/")
        common_depth = [common_depth, parts.length - 1].min
        
        common_depth.times do |i|
          if parts[i] != first_parts[i]
            common_depth = i
            break
          end
        end
        
        break if common_depth == 0
      end
      
      # Return common root if any
      common_depth > 0 ? first_parts[0...common_depth].last : nil
    end
  end
end