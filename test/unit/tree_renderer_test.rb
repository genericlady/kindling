# frozen_string_literal: true

require_relative "../test_helper"

class TreeRendererTest < Minitest::Test
  def test_empty_paths_returns_empty_string
    assert_equal "", Kindling::TreeRenderer.render([])
  end

  def test_single_file
    paths = ["README.md"]
    expected = <<~TREE.chomp
      └── README.md
    TREE

    assert_equal expected, Kindling::TreeRenderer.render(paths)
  end

  def test_multiple_files_in_root
    paths = ["README.md", "Gemfile", "Rakefile"]
    expected = <<~TREE.chomp
      ├── Gemfile
      ├── README.md
      └── Rakefile
    TREE

    assert_equal expected, Kindling::TreeRenderer.render(paths)
  end

  def test_nested_directories
    paths = [
      "app/models/user.rb",
      "app/models/post.rb",
      "app/controllers/users_controller.rb"
    ]

    expected = <<~TREE.chomp
      app/
      └── app/
          ├── controllers/
          │   └── users_controller.rb
          └── models/
              ├── post.rb
              └── user.rb
    TREE

    assert_equal expected, Kindling::TreeRenderer.render(paths, root_name: "app")
  end

  def test_mixed_files_and_directories
    paths = [
      "README.md",
      "src/main.rb",
      "src/lib/helper.rb",
      "test/test_helper.rb"
    ]

    expected = <<~TREE.chomp
      ├── src/
      │   ├── lib/
      │   │   └── helper.rb
      │   └── main.rb
      ├── test/
      │   └── test_helper.rb
      └── README.md
    TREE

    assert_equal expected, Kindling::TreeRenderer.render(paths)
  end

  def test_deep_nesting
    paths = [
      "a/b/c/d/e/file.txt"
    ]

    expected = <<~TREE.chomp
      a/
      └── a/
          └── b/
              └── c/
                  └── d/
                      └── e/
                          └── file.txt
    TREE

    assert_equal expected, Kindling::TreeRenderer.render(paths, root_name: "a")
  end

  def test_sorts_directories_before_files
    paths = [
      "src/file2.rb",
      "src/dir/nested.rb",
      "src/file1.rb"
    ]

    expected = <<~TREE.chomp
      src/
      └── src/
          ├── dir/
          │   └── nested.rb
          ├── file1.rb
          └── file2.rb
    TREE

    assert_equal expected, Kindling::TreeRenderer.render(paths, root_name: "src")
  end

  def test_alphabetical_sorting_within_type
    paths = [
      "zebra.txt",
      "apple.txt",
      "banana/file.txt",
      "cherry/file.txt"
    ]

    expected = <<~TREE.chomp
      ├── banana/
      │   └── file.txt
      ├── cherry/
      │   └── file.txt
      ├── apple.txt
      └── zebra.txt
    TREE

    assert_equal expected, Kindling::TreeRenderer.render(paths)
  end

  def test_unicode_filenames
    paths = [
      "café/menü.txt",
      "über.rb",
      "naïve.txt"
    ]

    expected = <<~TREE.chomp
      ├── café/
      │   └── menü.txt
      ├── naïve.txt
      └── über.rb
    TREE

    assert_equal expected, Kindling::TreeRenderer.render(paths)
  end

  def test_with_custom_root_name
    paths = ["src/main.rb"]
    expected = <<~TREE.chomp
      my-project/
      └── src/
          └── main.rb
    TREE

    assert_equal expected, Kindling::TreeRenderer.render(paths, root_name: "my-project")
  end

  def test_complex_tree_structure
    paths = [
      "README.md",
      "LICENSE",
      "src/main.rb",
      "src/utils/string_helper.rb",
      "src/utils/file_helper.rb",
      "src/models/user.rb",
      "src/models/post.rb",
      "test/unit/user_test.rb",
      "test/integration/api_test.rb",
      "docs/README.md",
      "docs/api/endpoints.md"
    ]

    expected = <<~TREE.chomp
      project/
      ├── docs/
      │   ├── api/
      │   │   └── endpoints.md
      │   └── README.md
      ├── src/
      │   ├── models/
      │   │   ├── post.rb
      │   │   └── user.rb
      │   ├── utils/
      │   │   ├── file_helper.rb
      │   │   └── string_helper.rb
      │   └── main.rb
      ├── test/
      │   ├── integration/
      │   │   └── api_test.rb
      │   └── unit/
      │       └── user_test.rb
      ├── LICENSE
      └── README.md
    TREE

    assert_equal expected, Kindling::TreeRenderer.render(paths, root_name: "project")
  end
end
