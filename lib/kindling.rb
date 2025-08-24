# frozen_string_literal: true

require "gtk3"
require "gio2"
require "find"
require "pathname"
require "set"
require "fileutils"

# Main module for Kindling file tree clipboard tool
module Kindling
  VERSION = "0.1.0"
  
  class Error < StandardError; end
  
  # Load all components
  require_relative "kindling/logging"
  require_relative "kindling/config"
  require_relative "kindling/indexer"
  require_relative "kindling/fuzzy"
  require_relative "kindling/selection"
  require_relative "kindling/tree_renderer"
  require_relative "kindling/clipboard"
  require_relative "kindling/app"
  
  # UI components
  require_relative "kindling/ui/window"
  require_relative "kindling/ui/header"
  require_relative "kindling/ui/file_list"
  require_relative "kindling/ui/preview"
end