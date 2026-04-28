require "test_helper"
require "rails_vitals/mcp/tools/base"
require "rails_vitals/mcp/tool_registry"
require "rails_vitals/mcp/tools/get_slow_queries"

class RailsVitalsMCPToolsGetSlowQueriesTest < ActiveSupport::TestCase
  GetSlowQueries = RailsVitals::MCP::Tools::GetSlowQueries
  Store = RailsVitals::Store

  RecordDouble = Struct.new(:endpoint, :id, :queries)

  def make_record(endpoint: "PostsController#index", id: "abc123", queries: [])
    RecordDouble.new(endpoint, id, queries)
  end

  def make_query(sql: "SELECT * FROM posts WHERE id = ?", duration_ms: 200)
    { sql: sql, duration_ms: duration_ms }
  end

  def call_tool(params: {}, records: [])
    stub_store = Store.new(100)
    records.each { |r| stub_store.push(r) }

    with_stub(RailsVitals, :store, stub_store) do
      GetSlowQueries.new.call(params)
    end
  end

  # --- no data ---

  test "#call returns no-data response when store is empty" do
    with_stub(RailsVitals, :store, Store.new(100)) do
      result = GetSlowQueries.new.call({})

      assert_equal 0, result[:total_slow_queries]
      assert_equal 0, result[:shown]
      assert_equal [], result[:queries]
      assert_includes result[:message], "No requests recorded"
    end
  end

  test "#call returns no-slow-queries response when nothing exceeds threshold" do
    record = make_record(queries: [ make_query(duration_ms: 50) ])
    result = call_tool(params: { threshold_ms: 100 }, records: [ record ])

    assert_equal 0, result[:total_slow_queries]
    assert_equal 0, result[:shown]
    assert_equal [], result[:queries]
    assert_includes result[:message], "No queries exceeded"
  end

  # --- threshold ---

  test "#call uses config default threshold when not given" do
    record = make_record(queries: [
      make_query(duration_ms: 50),
      make_query(duration_ms: 200)
    ])
    result = call_tool(records: [ record ])

    assert_equal 1, result[:total_slow_queries]
    assert_equal RailsVitals.config.mcp_slow_query_threshold_ms, result[:threshold_ms]
  end

  test "#call includes queries that exactly meet the threshold" do
    record = make_record(queries: [ make_query(duration_ms: 100) ])
    result = call_tool(params: { threshold_ms: 100 }, records: [ record ])

    assert_equal 1, result[:total_slow_queries]
  end

  test "#call excludes queries below threshold" do
    record = make_record(queries: [
      make_query(duration_ms: 300),
      make_query(duration_ms: 99),
      make_query(duration_ms: 150)
    ])
    result = call_tool(params: { threshold_ms: 100 }, records: [ record ])

    assert_equal 2, result[:total_slow_queries]
  end

  test "#call accepts string threshold_ms key from JSON params" do
    record = make_record(queries: [ make_query(duration_ms: 200) ])
    result = call_tool(params: { "threshold_ms" => 100 }, records: [ record ])

    assert_equal 1, result[:total_slow_queries]
  end

  test "#call echoes threshold_ms in response" do
    record = make_record(queries: [ make_query(duration_ms: 200) ])
    result = call_tool(params: { threshold_ms: 50 }, records: [ record ])

    assert_equal 50, result[:threshold_ms]
  end

  # --- ordering ---

  test "#call orders results by duration desc" do
    record = make_record(queries: [
      make_query(sql: "slow",    duration_ms: 150),
      make_query(sql: "slowest", duration_ms: 400),
      make_query(sql: "medium",  duration_ms: 200)
    ])
    result = call_tool(params: { threshold_ms: 100 }, records: [ record ])

    durations = result[:queries].map { |q| q[:duration_ms] }
    assert_equal durations.sort.reverse, durations
  end

  # --- limit ---

  test "#call respects limit param" do
    record = make_record(queries: Array.new(5) { make_query(duration_ms: 200) })
    result = call_tool(params: { threshold_ms: 100, limit: 2 }, records: [ record ])

    assert_equal 5, result[:total_slow_queries]
    assert_equal 2, result[:shown]
    assert_equal 2, result[:queries].size
  end

  test "#call accepts string limit key from JSON params" do
    record = make_record(queries: Array.new(3) { make_query(duration_ms: 200) })
    result = call_tool(params: { threshold_ms: 100, "limit" => 2 }, records: [ record ])

    assert_equal 2, result[:shown]
  end

  test "#call defaults to #{GetSlowQueries::DEFAULT_LIMIT} patterns when limit is not given" do
    record = make_record(queries: Array.new(15) { make_query(duration_ms: 200) })
    result = call_tool(params: { threshold_ms: 100 }, records: [ record ])

    assert_equal 15, result[:total_slow_queries]
    assert_equal GetSlowQueries::DEFAULT_LIMIT, result[:shown]
    assert_equal GetSlowQueries::DEFAULT_LIMIT, result[:queries].size
  end

  # --- serialization ---

  test "#call serializes sql duration_ms endpoint and request_id" do
    query  = make_query(sql: "SELECT * FROM users", duration_ms: 250.7)
    record = make_record(endpoint: "UsersController#index", id: "req123", queries: [ query ])
    result = call_tool(params: { threshold_ms: 100 }, records: [ record ])
    q = result[:queries].first

    assert_equal "SELECT * FROM users", q[:sql]
    assert_equal 250.7, q[:duration_ms]
    assert_equal "UsersController#index", q[:endpoint]
    assert_equal "req123", q[:request_id]
  end

  test "#call aggregates slow queries across multiple records" do
    r1 = make_record(endpoint: "PostsController#index", id: "r1",
                     queries: [ make_query(duration_ms: 300) ])
    r2 = make_record(endpoint: "UsersController#show", id: "r2",
                     queries: [ make_query(duration_ms: 200) ])
    result = call_tool(params: { threshold_ms: 100 }, records: [ r1, r2 ])

    assert_equal 2, result[:total_slow_queries]
    endpoints = result[:queries].map { |q| q[:endpoint] }
    assert_includes endpoints, "PostsController#index"
    assert_includes endpoints, "UsersController#show"
  end

  # --- registration ---

  test "GetSlowQueries is registered in ToolRegistry under its TOOL_NAME" do
    assert_equal GetSlowQueries, RailsVitals::MCP::ToolRegistry.find(GetSlowQueries::TOOL_NAME)
  end

  test ".definition includes name description and inputSchema with threshold_ms and limit" do
    defn = GetSlowQueries.definition

    assert_equal GetSlowQueries::TOOL_NAME, defn[:name]
    assert defn[:description].length > 10
    assert defn[:inputSchema][:properties].key?(:threshold_ms)
    assert defn[:inputSchema][:properties].key?(:limit)
  end
end
