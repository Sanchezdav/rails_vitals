require "test_helper"
require "digest"

class RailsVitalsNPlusOnesControllerTest < ActionDispatch::IntegrationTest
  RecordDouble = Struct.new(:id, :endpoint, :n_plus_one_patterns, :score, :duration_ms, :queries, keyword_init: true) do
    def total_query_count
      queries.size
    end
  end

  StoreDouble = Struct.new(:all)

  test "GET /rails_vitals/n_plus_ones returns index response with aggregated pattern rows" do
    records = [
      RecordDouble.new(id: "r1", endpoint: "UsersController#index", n_plus_one_patterns: { "SELECT * FROM users WHERE users.id = 1" => 3 }, score: 55, duration_ms: 30.0, queries: [ build_query(sql: "SELECT * FROM users", duration_ms: 2.0) ])
    ]

    patterns = [
      {
        pattern: "SELECT * FROM users WHERE users.id = ?",
        occurrences: 3,
        endpoints: { "UsersController#index" => 1 },
        fix_suggestion: { code: "User.includes(:posts)", description: "Eager load", owner: "User", association: "posts" }
      }
    ]

    with_stub(RailsVitals, :store, StoreDouble.new(records)) do
      with_stub(RailsVitals::Analyzers::NPlusOneAggregator, :aggregate, patterns) do
        get "/rails_vitals/n_plus_ones"
        assert_response :success
        assert_includes response.body, "N+1 Patterns"
        assert_includes response.body, "User.includes(:posts)"
      end
    end
  end

  test "GET /rails_vitals/n_plus_ones/:id returns 404 response when pattern id is not found" do
    records = [ RecordDouble.new(id: "r1", endpoint: "UsersController#index", n_plus_one_patterns: {}, score: 60, duration_ms: 30.0, queries: []) ]

    with_stub(RailsVitals, :store, StoreDouble.new(records)) do
      with_stub(RailsVitals::Analyzers::NPlusOneAggregator, :aggregate, []) do
        get "/rails_vitals/n_plus_ones/missing"
        assert_response :not_found
        assert_includes response.body, "Pattern not found"
      end
    end
  end

  test "GET /rails_vitals/n_plus_ones/:id returns impact simulator response for selected pattern" do
    pattern = {
      pattern: "SELECT * FROM users WHERE users.id = ?",
      occurrences: 4,
      endpoints: { "UsersController#index" => 2 },
      fix_suggestion: { code: "User.includes(:posts)", description: "Eager load", owner: "User", association: "posts" }
    }
    pattern_id = Digest::MD5.hexdigest(pattern[:pattern])[0..7]
    records = [
      RecordDouble.new(
        id: "r1",
        endpoint: "UsersController#index",
        n_plus_one_patterns: { "SELECT * FROM users WHERE users.id = 1" => 3 },
        score: 60,
        duration_ms: 30.0,
        queries: [ build_query(sql: "SELECT * FROM users", duration_ms: 2.0) ]
      )
    ]

    with_stub(RailsVitals, :store, StoreDouble.new(records)) do
      with_stub(RailsVitals::Analyzers::NPlusOneAggregator, :aggregate, [ pattern ]) do
        get "/rails_vitals/n_plus_ones/#{pattern_id}"
        assert_response :success
        assert_includes response.body, "Impact Simulator"
        assert_includes response.body, "Total Time Recovered"
      end
    end
  end
end
