require "test_helper"

class RailsVitalsNPlusOneAggregatorTest < ActiveSupport::TestCase
  RecordDouble = Struct.new(:endpoint, :n_plus_one_patterns, keyword_init: true)

  test ".aggregate returns Array<Hash> sorted by :occurrences desc with endpoint frequency map" do
    users_sql_1 = "SELECT * FROM users WHERE users.id = 1"
    users_sql_2 = "SELECT * FROM users WHERE users.id = 2"
    posts_sql = "SELECT * FROM posts WHERE posts.id = 9"

    records = [
      RecordDouble.new(endpoint: "UsersController#index", n_plus_one_patterns: { users_sql_1 => 4, posts_sql => 2 }),
      RecordDouble.new(endpoint: "UsersController#show", n_plus_one_patterns: { users_sql_2 => 3 })
    ]

    result = RailsVitals::Analyzers::NPlusOneAggregator.aggregate(records)

    assert_kind_of Array, result
    assert_equal 2, result.size

    top = result.first
    assert_equal "SELECT * FROM users WHERE users.id = ?", top[:pattern]
    assert_equal 7, top[:occurrences]
    assert_equal({ "UsersController#index" => 1, "UsersController#show" => 1 }, top[:endpoints])
  end

  test ".aggregate returns fix_suggestion Hash with keys :code :description :owner :association" do
    records = [
      RecordDouble.new(
        endpoint: "UsersController#index",
        n_plus_one_patterns: { "SELECT * FROM widgets WHERE widgets.user_id = 3" => 3 }
      )
    ]

    result = RailsVitals::Analyzers::NPlusOneAggregator.aggregate(records)
    suggestion = result.first[:fix_suggestion]

    assert_kind_of Hash, suggestion
    assert_equal [ :code, :description, :owner, :association ], suggestion.keys
    assert_kind_of String, suggestion[:code]
    assert_kind_of String, suggestion[:description]
  end

  test ".aggregate returns empty Array when no record has n_plus_one_patterns" do
    records = [
      RecordDouble.new(endpoint: "UsersController#index", n_plus_one_patterns: {}),
      RecordDouble.new(endpoint: "UsersController#show", n_plus_one_patterns: {})
    ]

    result = RailsVitals::Analyzers::NPlusOneAggregator.aggregate(records)

    assert_equal [], result
  end

  test ".aggregate returns single normalized pattern key for escaped quotes and numeric literals" do
    sql_one = 'SELECT * FROM \\\"users\\\" WHERE \\\"users\\\".\\\"id\\\" = 1'
    sql_two = 'SELECT * FROM \\\"users\\\" WHERE \\\"users\\\".\\\"id\\\" = 2'

    records = [
      RecordDouble.new(endpoint: "UsersController#index", n_plus_one_patterns: { sql_one => 2 }),
      RecordDouble.new(endpoint: "UsersController#show", n_plus_one_patterns: { sql_two => 1 })
    ]

    result = RailsVitals::Analyzers::NPlusOneAggregator.aggregate(records)

    assert_equal 1, result.size
    assert_equal "SELECT * FROM \\\"users\\\" WHERE \\\"users\\\".\\\"id\\\" = ?", result.first[:pattern]
    assert_equal 3, result.first[:occurrences]
  end
end
