require "test_helper"
require "rails_vitals/mcp/tools/base"
require "rails_vitals/mcp/tool_registry"
require "rails_vitals/mcp/tools/get_request_log"

class RailsVitalsMCPToolsGetRequestLogTest < ActiveSupport::TestCase
  GetRequestLog = RailsVitals::MCP::Tools::GetRequestLog
  Store = RailsVitals::Store

  RecordDouble = Struct.new(:id, :controller, :action, :score, :label,
                            :n_plus_one_patterns, :duration_ms, :recorded_at,
                            :_queries, keyword_init: true) do
    def endpoint = "#{controller}##{action}"
    def total_query_count = _queries.size
    def total_db_time_ms = _queries.sum { |q| q[:duration_ms] }
  end

  def make_record(controller: "PostsController", action: "index", score: 80,
                  label: "Acceptable", n1_patterns: {}, duration_ms: 50.0,
                  queries: [], recorded_at: Time.now, id: SecureRandom.hex(4))
    RecordDouble.new(
      id: id,
      controller: controller,
      action: action,
      score: score,
      label: label,
      n_plus_one_patterns: n1_patterns,
      duration_ms: duration_ms,
      recorded_at: recorded_at,
      _queries: queries
    )
  end

  def call_tool(params: {}, records: [])
    stub_store = Store.new(100)
    records.each { |r| stub_store.push(r) }

    with_stub(RailsVitals, :store, stub_store) do
      GetRequestLog.new.call(params)
    end
  end

  # --- no data ---

  test "#call returns no-data response when store is empty" do
    with_stub(RailsVitals, :store, Store.new(100)) do
      result = GetRequestLog.new.call({})

      assert_equal 0, result[:total_requests]
      assert_equal 0, result[:shown]
      assert_equal [], result[:requests]
      assert_includes result[:message], "No requests recorded"
    end
  end

  test "#call returns no-match response when controller filter matches nothing" do
    record = make_record(controller: "PostsController")
    result = call_tool(params: { controller: "Feed" }, records: [ record ])

    assert_equal 0, result[:total_requests]
    assert_equal 0, result[:shown]
    assert_equal [], result[:requests]
    assert_includes result[:message], "Feed"
  end

  # --- ordering ---

  test "#call returns requests most recent first" do
    t = Time.now
    r1 = make_record(id: "old", recorded_at: t - 10)
    r2 = make_record(id: "mid", recorded_at: t - 5)
    r3 = make_record(id: "new", recorded_at: t)
    result = call_tool(records: [ r1, r2, r3 ])

    assert_equal [ "new", "mid", "old" ], result[:requests].map { |r| r[:request_id] }
  end

  # --- limit ---

  test "#call respects limit and sets shown accordingly" do
    records = Array.new(5) { make_record }
    result = call_tool(params: { limit: 2 }, records: records)

    assert_equal 5, result[:total_requests]
    assert_equal 2, result[:shown]
    assert_equal 2, result[:requests].size
  end

  test "#call accepts string limit key from JSON params" do
    records = Array.new(3) { make_record }
    result = call_tool(params: { "limit" => 2 }, records: records)

    assert_equal 2, result[:shown]
  end

  test "#call defaults to #{GetRequestLog::DEFAULT_LIMIT} when limit is not given" do
    records = Array.new(25) { make_record }
    result = call_tool(records: records)

    assert_equal 25, result[:total_requests]
    assert_equal GetRequestLog::DEFAULT_LIMIT, result[:shown]
    assert_equal GetRequestLog::DEFAULT_LIMIT, result[:requests].size
  end

  # --- controller filter ---

  test "#call filters by controller case-insensitively" do
    feed = make_record(controller: "FeedController")
    posts = make_record(controller: "PostsController")
    result = call_tool(params: { controller: "feed" }, records: [ feed, posts ])

    assert_equal 1, result[:total_requests]
    assert_equal "FeedController#index", result[:requests].first[:endpoint]
  end

  test "#call supports partial controller match" do
    feed = make_record(controller: "FeedController")
    posts = make_record(controller: "PostsController")
    result = call_tool(params: { controller: "Controller" }, records: [ feed, posts ])

    assert_equal 2, result[:total_requests]
  end

  test "#call accepts string controller key from JSON params" do
    feed = make_record(controller: "FeedController")
    result = call_tool(params: { "controller" => "Feed" }, records: [ feed ])

    assert_equal 1, result[:total_requests]
  end

  test "#call echoes controller_filter in response" do
    result = call_tool(params: { controller: "Feed" }, records: [ make_record(controller: "FeedController") ])

    assert_equal "Feed", result[:controller_filter]
  end

  test "#call sets controller_filter to nil when no filter given" do
    result = call_tool(records: [ make_record ])

    assert_nil result[:controller_filter]
  end

  # --- serialization ---

  test "#call serializes all request fields" do
    t = Time.parse("2026-04-27 09:15:00")
    record = make_record(
      id: "req1",
      controller: "FeedController",
      action: "index",
      score: 75,
      label: "Acceptable",
      n1_patterns: { "pattern_a" => 3, "pattern_b" => 2 },
      duration_ms: 148.9,
      queries: [ { duration_ms: 20.0 }, { duration_ms: 10.5 } ],
      recorded_at: t
    )
    result = call_tool(records: [ record ])
    r = result[:requests].first

    assert_equal "req1", r[:request_id]
    assert_equal "FeedController#index", r[:endpoint]
    assert_equal 75, r[:score]
    assert_equal "Acceptable", r[:grade]
    assert_equal 2, r[:query_count]
    assert_equal 30.5, r[:db_time_ms]
    assert_equal 2, r[:n1_patterns]
    assert_equal 148.9, r[:duration_ms]
    assert_equal "09:15:00", r[:recorded_at]
  end

  # --- registration ---

  test "GetRequestLog is registered in ToolRegistry under its TOOL_NAME" do
    assert_equal GetRequestLog, RailsVitals::MCP::ToolRegistry.find(GetRequestLog::TOOL_NAME)
  end

  test ".definition includes name description and inputSchema with controller and limit" do
    defn = GetRequestLog.definition

    assert_equal GetRequestLog::TOOL_NAME, defn[:name]
    assert defn[:description].length > 10
    assert defn[:inputSchema][:properties].key?(:controller)
    assert defn[:inputSchema][:properties].key?(:limit)
  end
end
