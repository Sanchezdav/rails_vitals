require "test_helper"
require "digest"

class NavigationTest < ActionDispatch::IntegrationTest
  RecordDouble = Struct.new(
    :id, :controller, :action, :score, :label, :color, :queries,
    :callbacks, :n_plus_one_patterns, :duration_ms, :response_status,
    :http_method, :recorded_at,
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

  class StoreDouble
    def initialize(records)
      @records = records
    end

    def all
      @records
    end

    def find(id)
      @records.find { |record| record.id == id }
    end
  end

  test "engine navigation routes return success responses and render primary page titles" do
    record = RecordDouble.new(
      id: "req_1",
      controller: "UsersController",
      action: "index",
      score: 55,
      label: "Warning",
      color: "amber",
      queries: [ build_query(sql: "SELECT * FROM users WHERE users.id = 1", duration_ms: 12.0) ],
      callbacks: [ { model: "User", kind: :save, duration_ms: 1.0 } ],
      n_plus_one_patterns: { "select * from users where users.id = ?" => 3 },
      duration_ms: 40.0,
      response_status: 200,
      http_method: "GET",
      recorded_at: Time.current
    )

    patterns = [
      {
        pattern: "SELECT * FROM users WHERE users.id = ?",
        occurrences: 3,
        endpoints: { "UsersController#index" => 1 },
        table: "users",
        foreign_key: "user_id",
        fix_suggestion: { code: "User.includes(:posts)", description: "Eager load", owner: "User", association: "posts" }
      }
    ]

    node = RailsVitals::Analyzers::AssociationMapper::ModelNode.new(
      name: "User",
      table: "users",
      depth: 0,
      position: { x: 100, y: 100 },
      associations: [],
      query_count: 1,
      avg_query_time_ms: 12.0,
      has_n1: true,
      n1_patterns: patterns
    )

    with_stub(RailsVitals, :store, StoreDouble.new([ record ])) do
      with_stub(RailsVitals::Analyzers::NPlusOneAggregator, :aggregate, patterns) do
        with_stub(RailsVitals::Analyzers::AssociationMapper, :build, [ [ node ], 280 ]) do
          get "/rails_vitals"
          assert_response :success
          assert_includes response.body, "Dashboard"

          get "/rails_vitals/requests"
          assert_response :success
          assert_includes response.body, "Request History"

          get "/rails_vitals/requests/req_1"
          assert_response :success
          assert_includes response.body, "Request Detail"

          get "/rails_vitals/heatmap"
          assert_response :success
          assert_includes response.body, "Endpoint Heatmap"

          get "/rails_vitals/models"
          assert_response :success
          assert_includes response.body, "Per-Model Breakdown"

          get "/rails_vitals/n_plus_ones"
          assert_response :success
          assert_includes response.body, "N+1 Patterns"

          pattern_id = Digest::MD5.hexdigest(patterns.first[:pattern])[0..7]
          get "/rails_vitals/n_plus_ones/#{pattern_id}"
          assert_response :success
          assert_includes response.body, "Impact Simulator"

          get "/rails_vitals/associations"
          assert_response :success
          assert_includes response.body, "Association Map"
        end
      end
    end
  end
end
