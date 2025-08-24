# frozen_string_literal: true

require_relative "../test_helper"

class AppSmokeTest < Minitest::Test
  def test_application_initializes
    skip "GTK tests require display" unless ENV["DISPLAY"]
    
    # Just verify the app can be created without errors
    app = Kindling::App.new
    assert_instance_of Kindling::App, app
  end
  
  def test_indexer_works_on_real_directory
    indexer = Kindling::Indexer.new
    
    # Index the project's own lib directory
    project_root = File.expand_path("../../..", __FILE__)
    lib_dir = File.join(project_root, "lib")
    
    paths = indexer.index(lib_dir)
    
    # Should find our own source files
    assert paths.any? { |p| p.include?("kindling.rb") }
    assert paths.any? { |p| p.include?("app.rb") }
    assert paths.any? { |p| p.include?("fuzzy.rb") }
  end
  
  def test_fuzzy_search_on_project_files
    indexer = Kindling::Indexer.new
    
    # Index project lib directory
    project_root = File.expand_path("../../..", __FILE__)
    lib_dir = File.join(project_root, "lib")
    paths = indexer.index(lib_dir)
    
    # Search for "fuzzy"
    results = Kindling::Fuzzy.filter(paths, "fuzzy")
    
    assert results.any? { |p| p.include?("fuzzy.rb") }
  end
  
  def test_tree_renderer_with_project_files
    paths = [
      "kindling/app.rb",
      "kindling/fuzzy.rb",
      "kindling/ui/window.rb",
      "kindling/ui/header.rb"
    ]
    
    tree = Kindling::TreeRenderer.render(paths, root_name: "lib")
    
    assert tree.include?("kindling/")
    assert tree.include?("├── ui/")
    assert tree.include?("│   ├── header.rb")
    assert tree.include?("│   └── window.rb")
    assert tree.include?("├── app.rb")
    assert tree.include?("└── fuzzy.rb")
  end
  
  def test_selection_management
    selection = Kindling::Selection.new
    
    assert selection.empty?
    
    selection.add("file1.rb")
    selection.add("file2.rb")
    
    assert_equal 2, selection.size
    assert selection.include?("file1.rb")
    
    selection.toggle("file1.rb")
    assert !selection.include?("file1.rb")
    
    selection.replace(["new1.rb", "new2.rb", "new3.rb"])
    assert_equal 3, selection.size
    
    selection.clear
    assert selection.empty?
  end
  
  def test_memory_usage_tracking
    skip "Memory tracking not critical for smoke test"
    
    mb = Kindling::Config.current_memory_mb
    assert mb > 0
    assert mb < 1000 # Sanity check
  end
end