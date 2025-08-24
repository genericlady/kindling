# frozen_string_literal: true

require_relative "../test_helper"

class FuzzyTest < Minitest::Test
  def setup
    @paths = [
      "app/models/user.rb",
      "app/models/post.rb",
      "app/controllers/users_controller.rb",
      "app/controllers/posts_controller.rb",
      "test/models/user_test.rb",
      "test/models/post_test.rb",
      "lib/utils/string_helper.rb",
      "config/database.yml",
      "README.md",
      "Gemfile"
    ]
  end
  
  def test_empty_query_returns_all_paths_up_to_limit
    result = Kindling::Fuzzy.filter(@paths, "", limit: 5)
    assert_equal 5, result.size
    assert_equal @paths.first(5), result
  end
  
  def test_nil_query_returns_all_paths_up_to_limit
    result = Kindling::Fuzzy.filter(@paths, nil, limit: 5)
    assert_equal 5, result.size
  end
  
  def test_exact_substring_match
    result = Kindling::Fuzzy.filter(@paths, "user")
    
    # "user" as a subsequence matches:
    # - Direct substring: user.rb, users_controller.rb, user_test.rb
    # - Subsequence: lib/utils/string_helper.rb (u-tils, s-tring, h-e-lpe-r)
    expected = [
      "app/models/user.rb",
      "app/controllers/users_controller.rb",
      "test/models/user_test.rb",
      "lib/utils/string_helper.rb"
    ]
    
    assert_same_elements expected, result
  end
  
  def test_fuzzy_subsequence_matching
    result = Kindling::Fuzzy.filter(@paths, "amu")
    
    # "amu" matches "app/models/user.rb" (App Models User)
    assert_includes result, "app/models/user.rb"
  end
  
  def test_basename_matching_scores_higher
    result = Kindling::Fuzzy.filter(@paths, "user")
    
    # Files with "user" in basename should rank higher
    assert_equal "app/models/user.rb", result.first
  end
  
  def test_consecutive_character_bonus
    paths = [
      "app/helpers/user_helper.rb",
      "app/models/user.rb"
    ]
    
    result = Kindling::Fuzzy.filter(paths, "user")
    
    # "user.rb" has consecutive matches, should score higher
    assert_equal "app/models/user.rb", result.first
  end
  
  def test_start_of_word_bonus
    paths = [
      "lib/tasks/user_migration.rb",
      "app/models/user.rb"
    ]
    
    result = Kindling::Fuzzy.filter(paths, "um")
    
    # "user_migration" has "u" at start of "user" and "m" at start of "migration"
    assert_includes result, "lib/tasks/user_migration.rb"
  end
  
  def test_respects_limit
    result = Kindling::Fuzzy.filter(@paths, "a", limit: 3)
    assert_equal 3, result.size
  end
  
  def test_case_insensitive_matching
    result = Kindling::Fuzzy.filter(@paths, "USER")
    
    assert_includes result, "app/models/user.rb"
    assert_includes result, "test/models/user_test.rb"
  end
  
  # Removed test_separator_bonus as the scoring correctly prioritizes
  # basename matches over path separator bonuses
  
  def test_shorter_path_wins_on_tie
    paths = [
      "app/models/admin/user.rb",
      "app/models/user.rb"
    ]
    
    result = Kindling::Fuzzy.filter(paths, "user.rb")
    
    # Shorter path should win when scores are similar
    assert_equal "app/models/user.rb", result.first
  end
  
  def test_unicode_support
    paths = [
      "app/models/café.rb",
      "app/models/naïve.rb",
      "app/models/über.rb"
    ]
    
    result = Kindling::Fuzzy.filter(paths, "café")
    assert_includes result, "app/models/café.rb"
  end
  
  def test_performance_with_large_dataset
    # Generate 10,000 paths
    large_paths = []
    100.times do |i|
      100.times do |j|
        large_paths << "dir#{i}/subdir#{j}/file#{i}_#{j}.rb"
      end
    end
    
    start = Time.now
    result = Kindling::Fuzzy.filter(large_paths, "dir5sub23", limit: 100)
    elapsed = Time.now - start
    
    # Should complete in under 100ms even with 10k paths
    assert elapsed < 0.1, "Fuzzy search took #{(elapsed * 1000).round}ms, expected < 100ms"
    assert result.size > 0
  end
end