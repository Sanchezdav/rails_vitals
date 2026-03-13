require "test_helper"

class RailsVitalsRequestsControllerTest < ActionDispatch::IntegrationTest
  RecordDouble = Struct.new(
    :id, :controller, :action, :score, :label, :color,
    :queries, :callbacks, :n_plus_one_patterns, :duration_ms, :recorded_at,
    :http_method, :response_status,
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
      callbacks.sum { |callback| callback[:duration_ms] }
    end

    def slowest_queries(limit = 3)
      queries.sort_by { |query| -query[:duration_ms] }.first(limit)
    end
  end

  StoreDouble = Struct.new(:all) do
    def find(id)
      all.find { |record| record.id == id }
    end
  end

  test "GET /rails_vitals/requests returns only records in selected score bracket when score filter is provided" do
    records = [
      build_record(id: "critical", score: 40, controller: "UsersController", action: "index", n_plus_one_patterns: {}),
      build_record(id: "healthy", score: 95, controller: "PostsController", action: "show", n_plus_one_patterns: {})
    ]

    with_stub(RailsVitals, :store, StoreDouble.new(records)) do
      get "/rails_vitals/requests", params: { score: "critical" }
      assert_response :success
      assert_includes response.body, "UsersController#index"
      refute_includes response.body, "PostsController#show"
    end
  end

  test "GET /rails_vitals/requests returns only records with non-empty n_plus_one_patterns when n_plus_one filter is provided" do
    records = [
      build_record(
        id: "n1",
        score: 60,
        controller: "UsersController",
        action: "index",
        n_plus_one_patterns: { "select * from users where users.id = ?" => 3 }
      ),
      build_record(id: "plain", score: 60, controller: "PostsController", action: "show", n_plus_one_patterns: {})
    ]

    with_stub(RailsVitals, :store, StoreDouble.new(records)) do
      get "/rails_vitals/requests", params: { n_plus_one: "1" }
      assert_response :success
      assert_includes response.body, "UsersController#index"
      refute_includes response.body, "PostsController#show"
    end
  end

  test "GET /rails_vitals/requests/:id returns 404 plain text when request is not found" do
    with_stub(RailsVitals, :store, StoreDouble.new([])) do
      get "/rails_vitals/requests/missing"
      assert_response :not_found
      assert_includes response.body, "Request not found"
    end
  end

  test "GET /rails_vitals/requests/:id returns request detail response with Query DNA table" do
    record = build_record(
      id: "r1",
      score: 70,
      controller: "UsersController",
      action: "show",
      n_plus_one_patterns: { "select * from users where users.id = ?" => 3 }
    )

    with_stub(RailsVitals, :store, StoreDouble.new([ record ])) do
      get "/rails_vitals/requests/r1"
      assert_response :success
      assert_includes response.body, "Request Detail"
      assert_includes response.body, "Query DNA"
      assert_includes response.body, "UsersController#show"
    end
  end

  private

  def build_record(id:, score:, controller:, action:, n_plus_one_patterns:)
    RecordDouble.new(
      id: id,
      controller: controller,
      action: action,
      score: score,
      label: "Label",
      color: "blue",
      queries: [ build_query(sql: "SELECT * FROM users WHERE users.id = 1", duration_ms: 12.3) ],
      callbacks: [ { model: "User", kind: :save, duration_ms: 1.0, called_at: Time.current } ],
      n_plus_one_patterns: n_plus_one_patterns,
      duration_ms: 35.0,
      recorded_at: Time.current,
      http_method: "GET",
      response_status: 200
    )
  end
end
