require "test_helper"

class RailsVitalsExplainsControllerTest < ActionDispatch::IntegrationTest
  RecordDouble = Struct.new(:id, :queries, keyword_init: true)
  StoreDouble = Struct.new(:all) do
    def find(id)
      all.find { |record| record.id == id }
    end
  end

  test "GET /rails_vitals/requests/:request_id/explain/:query_index returns 404 plain text when request is missing" do
    with_stub(RailsVitals, :store, StoreDouble.new([])) do
      get "/rails_vitals/requests/missing/explain/0"

      assert_response :not_found
      assert_includes response.body, "Request not found"
    end
  end

  test "GET /rails_vitals/requests/:request_id/explain/:query_index returns 404 plain text when query index is out of range" do
    record = RecordDouble.new(id: "r1", queries: [])

    with_stub(RailsVitals, :store, StoreDouble.new([ record ])) do
      get "/rails_vitals/requests/r1/explain/7"

      assert_response :not_found
      assert_includes response.body, "Query not found"
    end
  end

  test "GET /rails_vitals/requests/:request_id/explain/:query_index passes sql and binds to analyzer and renders analyzer output" do
    query = { sql: "SELECT * FROM users WHERE id = $1", binds: [ 42 ] }
    record = RecordDouble.new(id: "r1", queries: [ query ])

    captured_call = nil
    analyzer_result = RailsVitals::Analyzers::ExplainAnalyzer::Result.new(
      sql: query[:sql],
      plan: nil,
      warnings: [],
      suggestions: [],
      total_cost: nil,
      actual_time_ms: nil,
      rows_examined: nil,
      interpretation: nil,
      error: "EXPLAIN unavailable for this query"
    )

    analyze_stub = lambda do |sql, binds: []|
      captured_call = { sql: sql, binds: binds }
      analyzer_result
    end

    with_stub(RailsVitals, :store, StoreDouble.new([ record ])) do
      with_stub(RailsVitals::Analyzers::ExplainAnalyzer, :analyze, analyze_stub) do
        get "/rails_vitals/requests/r1/explain/0"

        assert_response :success
        assert_includes response.body, "EXPLAIN Visualizer"
        assert_includes response.body, "EXPLAIN unavailable for this query"
      end
    end

    assert_equal({ sql: query[:sql], binds: query[:binds] }, captured_call)
  end
end
