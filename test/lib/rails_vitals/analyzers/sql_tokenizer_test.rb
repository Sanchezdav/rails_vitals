require "test_helper"

class RailsVitalsSqlTokenizerTest < ActiveSupport::TestCase
  test ".tokenize returns Result struct with tokens complexity label risk and repetition fields" do
    sql = "SELECT * FROM users WHERE users.user_id = 42 ORDER BY created_at DESC LIMIT 10"

    result = RailsVitals::Analyzers::SqlTokenizer.tokenize(sql, all_queries: [ { sql: sql } ])

    assert_kind_of RailsVitals::Analyzers::SqlTokenizer::Result, result
    assert_kind_of Array, result.tokens
    assert_kind_of Integer, result.complexity
    assert_kind_of Hash, result.complexity_label
    assert_kind_of Symbol, result.risk
    assert_kind_of Integer, result.repetition_count

    assert result.tokens.any? { |token| token[:type] == :from }
    assert result.tokens.any? { |token| token[:type] == :where }

    assert_equal [ :label, :color ], result.complexity_label.keys
    assert_includes [ :healthy, :neutral, :warning, :danger ], result.risk
  end

  test ".tokenize returns :danger when danger and lower-risk tokens coexist" do
    sql = "SELECT * FROM users WHERE users.user_id = 7"

    result = RailsVitals::Analyzers::SqlTokenizer.tokenize(sql)

    assert_equal :danger, result.risk
  end

  test ".tokenize returns repetition_bar as empty Array when repetition count is 1 or less" do
    sql = "SELECT id FROM users WHERE id = 1"

    result = RailsVitals::Analyzers::SqlTokenizer.tokenize(sql, all_queries: [ { sql: sql } ])

    assert_equal 1, result.repetition_count
    assert_equal [], result.repetition_bar
  end

  test ".tokenize returns repetition_bar Hash with keys :count :filled :empty when query repeats" do
    query_a = { sql: "SELECT * FROM users WHERE users.id = 1" }
    query_b = { sql: "SELECT * FROM users WHERE users.id = 2" }
    query_c = { sql: "SELECT * FROM users WHERE users.id = 3" }

    result = RailsVitals::Analyzers::SqlTokenizer.tokenize(query_a[:sql], all_queries: [ query_a, query_b, query_c ])

    assert_equal 3, result.repetition_count
    assert_kind_of Hash, result.repetition_bar
    assert_equal [ :count, :filled, :empty ], result.repetition_bar.keys
    assert_equal 3, result.repetition_bar[:count]
    assert_equal 20, result.repetition_bar[:filled] + result.repetition_bar[:empty]
  end

  test ".tokenize returns complexity_label Hash with Simple Moderate or Complex label based on complexity" do
    simple = RailsVitals::Analyzers::SqlTokenizer.tokenize("SELECT id FROM users")
    moderate = RailsVitals::Analyzers::SqlTokenizer.tokenize("SELECT id FROM users WHERE users.user_id = 1 ORDER BY created_at")
    complex = RailsVitals::Analyzers::SqlTokenizer.tokenize("SELECT * FROM users WHERE users.user_id = 1 OFFSET 10")

    assert_equal "Simple", simple.complexity_label[:label]
    assert_equal "Moderate", moderate.complexity_label[:label]
    assert_equal "Complex", complex.complexity_label[:label]
  end
end
