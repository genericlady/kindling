# frozen_string_literal: true

require_relative "../test_helper"

class SelectionTest < Minitest::Test
  def setup
    @selection = Kindling::Selection.new
  end

  def test_initially_empty
    assert_empty @selection
    assert_equal 0, @selection.size
    refute @selection.any?
  end

  def test_add_path
    @selection.add("path/to/file.rb")
    assert @selection.include?("path/to/file.rb")
    assert_equal 1, @selection.size
    assert @selection.any?
  end

  def test_add_duplicate_path
    @selection.add("path/to/file.rb")
    @selection.add("path/to/file.rb")
    assert_equal 1, @selection.size
  end

  def test_remove_path
    @selection.add("path/to/file.rb")
    @selection.remove("path/to/file.rb")
    refute @selection.include?("path/to/file.rb")
    assert_empty @selection
  end

  def test_remove_nonexistent_path
    @selection.add("path/to/file.rb")
    @selection.remove("nonexistent.rb")
    assert_equal 1, @selection.size
  end

  def test_toggle_path
    # Toggle on
    @selection.toggle("path/to/file.rb")
    assert @selection.include?("path/to/file.rb")

    # Toggle off
    @selection.toggle("path/to/file.rb")
    refute @selection.include?("path/to/file.rb")
  end

  def test_replace_paths
    @selection.add("old/path.rb")
    @selection.replace(["new/path1.rb", "new/path2.rb"])

    refute @selection.include?("old/path.rb")
    assert @selection.include?("new/path1.rb")
    assert @selection.include?("new/path2.rb")
    assert_equal 2, @selection.size
  end

  def test_clear
    @selection.add("path1.rb")
    @selection.add("path2.rb")
    @selection.clear

    assert_empty @selection
    assert_equal 0, @selection.size
  end

  def test_count_alias
    @selection.add("path1.rb")
    @selection.add("path2.rb")
    assert_equal @selection.size, @selection.count
  end

  def test_enumerable_each
    paths = ["path1.rb", "path2.rb", "path3.rb"]
    paths.each { |p| @selection.add(p) }

    collected = []
    @selection.each { |p| collected << p }

    assert_equal paths.sort, collected.sort
  end

  def test_enumerable_methods
    paths = ["path1.rb", "path2.rb", "path3.rb"]
    paths.each { |p| @selection.add(p) }

    # Test various Enumerable methods
    assert_equal 3, @selection.count
    assert @selection.all? { |p| p.end_with?(".rb") }
    assert_includes @selection.map(&:upcase), "PATH1.RB"
  end

  def test_to_a_returns_sorted_array
    @selection.add("zebra.rb")
    @selection.add("apple.rb")
    @selection.add("banana.rb")

    result = @selection.to_a
    assert_equal ["apple.rb", "banana.rb", "zebra.rb"], result
    assert_instance_of Array, result
  end

  def test_works_with_nested_paths
    nested_paths = [
      "src/models/user.rb",
      "src/controllers/app.rb",
      "test/unit/user_test.rb"
    ]

    nested_paths.each { |p| @selection.add(p) }
    assert_equal nested_paths.size, @selection.size
    nested_paths.each { |p| assert @selection.include?(p) }
  end

  def test_handles_unicode_paths
    unicode_path = "path/to/文件.rb"
    @selection.add(unicode_path)
    assert @selection.include?(unicode_path)
  end
end
