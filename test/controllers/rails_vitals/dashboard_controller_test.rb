require "test_helper"

class RailsVitalsDashboardControllerTest < ActionDispatch::IntegrationTest
  RecordDouble = Struct.new(
    :id, :controller, :action, :score, :label, :color,
    :queries, :n_plus_one_patterns, :duration_ms, :recorded_at,
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

    def total_callback_time_ms
      0.0
    end
  end

  StoreDouble = Struct.new(:all) do
    def find(id)
      all.find { |record| record.id == id }
    end
  end

  test "GET /rails_vitals returns dashboard response with aggregate sections and endpoint rows" do
    records = [
      RecordDouble.new(
        id: "r1",
        controller: "UsersController",
        action: "index",
        score: 45,
        label: "Critical",
        color: "red",
        queries: [ build_query(sql: "SELECT * FROM users", duration_ms: 20.0) ],
        n_plus_one_patterns: { "select * from users where users.id = ?" => 3 },
        duration_ms: 80.0,
        recorded_at: Time.current
      ),
      RecordDouble.new(
        id: "r2",
        controller: "PostsController",
        action: "show",
        score: 92,
        label: "Healthy",
        color: "green",
        queries: [ build_query(sql: "SELECT * FROM posts", duration_ms: 5.0) ],
        n_plus_one_patterns: {},
        duration_ms: 25.0,
        recorded_at: Time.current
      )
    ]

    with_stub(RailsVitals, :store, StoreDouble.new(records)) do
      get "/rails_vitals"
      assert_response :success
      assert_includes response.body, "Dashboard"
      assert_includes response.body, "Requests Recorded"
      assert_includes response.body, "Top Offenders by Avg Score"
      assert_includes response.body, "UsersController#index"
    end
  end
end
