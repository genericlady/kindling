# frozen_string_literal: true

# Enable coverage if running full test suite
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
    add_filter "/vendor/"
  end
end

require "minitest/autorun"
require "minitest/reporters"

# Use spec-style output
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# Load the application
require_relative "../lib/kindling"

# Test helpers
module TestHelpers
  # Create a temporary directory with files for testing
  def with_temp_dir
    require "tmpdir"
    Dir.mktmpdir("kindling_test") do |dir|
      yield dir
    end
  end

  # Create a file tree structure from a hash
  # Example: create_files(dir, { "src" => { "main.rb" => "", "test.rb" => "" } })
  def create_files(root, structure)
    structure.each do |name, content|
      path = File.join(root, name)

      if content.is_a?(Hash)
        # Directory with nested structure
        FileUtils.mkdir_p(path)
        create_files(path, content)
      else
        # File with content
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
      end
    end
  end

  # Assert arrays are equal ignoring order
  def assert_same_elements(expected, actual, message = nil)
    assert_equal expected.sort, actual.sort, message
  end
end

# Include helpers in all tests
class Minitest::Test
  include TestHelpers
end
