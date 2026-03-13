require "test_helper"

class RailsVitalsHeatmapControllerTest < ActionDispatch::IntegrationTest
  RecordDouble = Struct.new(
    :controller, :action, :score, :queries, :n_plus_one_patterns, :total_callback_time_ms,
    keyword_init: true
  ) do
    def endpoint
      "#{controller}##{action}"
    end

    def total_query_count
      queries.size
    end

    def total_db_time_ms
      queries.sum { |query| query[:duration_ms] }
    end
  end

  StoreDouble = Struct.new(:all) do
    def find(_id)
      nil
    end
  end

  test "GET /rails_vitals/heatmap returns endpoint heatmap rows with averages and n_plus_one frequency" do
    records = [
      RecordDouble.new(
        controller: "UsersController",
        action: "index",
        score: 45,
        queries: [ build_query(sql: "SELECT * FROM users", duration_ms: 20.0) ],
        n_plus_one_patterns: { "select * from users where users.id = ?" => 3 },
        total_callback_time_ms: 3.1
      ),
      RecordDouble.new(
        controller: "UsersController",
        action: "index",
        score: 65,
        queries: [ build_query(sql: "SELECT * FROM users", duration_ms: 10.0) ],
        n_plus_one_patterns: {},
        total_callback_time_ms: 1.5
      )
    ]

    with_stub(RailsVitals, :store, StoreDouble.new(records)) do
      get "/rails_vitals/heatmap"
      assert_response :success
      assert_includes response.body, "Endpoint Heatmap"
      assert_includes response.body, "UsersController#index"
      assert_includes response.body, "N+1 Frequency"
    end
  end
end
