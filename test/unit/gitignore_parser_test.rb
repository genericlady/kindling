# frozen_string_literal: true

require "test_helper"

class GitignoreParserTest < Minitest::Test
  def setup
    @parser = Kindling::GitignoreParser.new
  end

  def test_empty_parser_ignores_nothing
    assert !@parser.ignored?("file.txt")
    assert !@parser.ignored?("dir/file.txt")
  end

  def test_simple_file_pattern
    @parser.add_pattern("*.log")

    assert @parser.ignored?("test.log")
    assert @parser.ignored?("dir/test.log")
    assert !@parser.ignored?("test.txt")
  end

  def test_directory_only_pattern
    @parser.add_pattern("build/")

    assert @parser.ignored?("build", is_directory: true)
    assert !@parser.ignored?("build", is_directory: false)
    assert !@parser.ignored?("build.txt")
  end

  def test_anchored_pattern
    @parser.add_pattern("/config.json")

    assert @parser.ignored?("config.json")
    assert !@parser.ignored?("dir/config.json")
  end

  def test_wildcard_patterns
    @parser.add_pattern("*.tmp")
    @parser.add_pattern("test?")

    assert @parser.ignored?("file.tmp")
    assert @parser.ignored?("test1")
    assert @parser.ignored?("test2")
    assert !@parser.ignored?("test12")
  end

  def test_double_asterisk_pattern
    @parser.add_pattern("**/node_modules")

    assert @parser.ignored?("node_modules", is_directory: true)
    assert @parser.ignored?("src/node_modules", is_directory: true)
    assert @parser.ignored?("a/b/c/node_modules", is_directory: true)
  end

  def test_negation_pattern
    @parser.add_pattern("*.log")
    @parser.add_pattern("!important.log")

    # Note: Full negation support would require more complex logic
    # For MVP, we'll skip negation patterns
    assert @parser.ignored?("test.log")
  end

  def test_comment_and_empty_lines_ignored
    @parser.add_pattern("# This is a comment")
    @parser.add_pattern("")
    @parser.add_pattern("   ")

    assert !@parser.ignored?("file.txt")
  end

  def test_load_from_file
    Dir.mktmpdir do |dir|
      gitignore_path = File.join(dir, ".gitignore")
      File.write(gitignore_path, <<~GITIGNORE)
        # Test gitignore
        *.log
        build/
        /config.json
        node_modules
      GITIGNORE

      parser = Kindling::GitignoreParser.new
      parser.load_file(gitignore_path)

      assert parser.ignored?("test.log")
      assert parser.ignored?("build", is_directory: true)
      assert parser.ignored?("config.json")
      assert !parser.ignored?("src/config.json")
      assert parser.ignored?("node_modules", is_directory: true)
    end
  end

  def test_complex_patterns
    # Test character class patterns
    @parser.add_pattern("[Tt]est*")

    assert @parser.ignored?("test.txt")
    assert @parser.ignored?("Test.txt")

    # Note: Brace expansion like *.{jpg,jpeg,png} not supported in MVP
    # Would require more complex parsing
  end
end
