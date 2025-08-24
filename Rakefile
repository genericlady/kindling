# frozen_string_literal: true

require "rake/testtask"

# Default task
task default: :test

# Test task
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

# Unit tests only
Rake::TestTask.new(:unit) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/unit/*_test.rb"]
  t.warning = false
end

# Integration tests only
Rake::TestTask.new(:integration) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/integration/*_test.rb"]
  t.warning = false
end

# Test with coverage
desc "Run tests with coverage"
task :coverage do
  ENV["COVERAGE"] = "true"
  Rake::Task["test"].invoke
end

# Lint with RuboCop
desc "Run RuboCop"
task :rubocop do
  sh "bundle exec rubocop"
end

# Lint with StandardRB
desc "Run StandardRB"
task :standard do
  sh "bundle exec standardrb"
end

# Lint task (runs both)
desc "Run all linters"
task lint: [:rubocop, :standard]

# Lint fix task (auto-fix issues)
namespace :lint do
  desc "Auto-fix linting issues"
  task :fix do
    puts "Auto-fixing with RuboCop..."
    sh "bundle exec rubocop -A"
    puts "\nAuto-fixing with StandardRB..."
    sh "bundle exec standardrb --fix"
  end
end

# Console task for debugging
desc "Open an interactive console"
task :console do
  require "irb"
  require_relative "lib/kindling"

  ARGV.clear
  IRB.start
end

# Run the application
desc "Run Kindling"
task :run do
  ruby "bin/kindling"
end

# Install dependencies
desc "Install dependencies"
task :bundle do
  sh "bundle install"
end

# Clean temporary files
desc "Clean temporary files"
task :clean do
  FileUtils.rm_rf("coverage")
  FileUtils.rm_rf("tmp")
  FileUtils.rm_f(".DS_Store")

  # Remove any .DS_Store files recursively
  Dir.glob("**/.DS_Store").each { |f| FileUtils.rm_f(f) }
end

# Development setup
desc "Setup development environment"
task setup: [:bundle] do
  puts "Development environment ready!"
  puts "Run 'rake test' to run tests"
  puts "Run 'rake run' or 'bin/kindling' to start the app"
end

# Performance benchmark (for development)
desc "Run performance benchmarks"
task :bench do
  require_relative "lib/kindling"

  puts "Running fuzzy search benchmark..."

  # Generate test data
  paths = []
  100.times do |i|
    100.times do |j|
      paths << "dir#{i}/subdir#{j}/file#{i}_#{j}.rb"
    end
  end

  puts "Testing with #{paths.size} paths"

  # Test queries
  queries = ["dir5", "file42", "sub99fi", "dir1sub2file"]

  queries.each do |query|
    start = Time.now
    results = Kindling::Fuzzy.filter(paths, query, limit: 100)
    elapsed = ((Time.now - start) * 1000).round(2)

    puts "Query '#{query}': #{results.size} results in #{elapsed}ms"
  end

  # Test tree rendering
  selected = paths.sample(50)
  start = Time.now
  tree = Kindling::TreeRenderer.render(selected)
  elapsed = ((Time.now - start) * 1000).round(2)

  puts "\nTree rendering (#{selected.size} paths): #{elapsed}ms"
  puts "Tree has #{tree.lines.count} lines"
end
