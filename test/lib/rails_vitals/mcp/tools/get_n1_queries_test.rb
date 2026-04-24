require "test_helper"
require "rails_vitals/mcp/tools/base"
require "rails_vitals/mcp/tool_registry"
require "rails_vitals/mcp/tools/get_n1_queries"

class RailsVitalsMCPToolsGetN1QueriesTest < ActiveSupport::TestCase
  GetN1Queries = RailsVitals::MCP::Tools::GetN1Queries
  Aggregator = RailsVitals::Analyzers::NPlusOneAggregator
  Store = RailsVitals::Store

  PATTERN_STUB = {
    pattern: "select * from posts where user_id = ?",
    occurrences:  12,
    table: "posts",
    foreign_key: "user_id",
    endpoints: { "PostsController#index" => 8, "FeedController#show" => 4 },
    fix_suggestion: {
      code: "User.includes(:posts)",
      description: "Eager load :posts on User to eliminate this N+1",
      owner: "User",
      association: "posts"
    }
  }.freeze

  PATTERN_STUB_2 = {
    pattern: "select * from comments where post_id = ?",
    occurrences:  5,
    table: "comments",
    foreign_key: "post_id",
    endpoints: { "PostsController#show" => 5 },
    fix_suggestion: {
      code: "Post.includes(:comments)",
      description: "Eager load :comments on Post to eliminate this N+1",
      owner: "Post",
      association: "comments"
    }
  }.freeze

  def call_tool(params: {}, aggregate_result:)
    stub_store = Store.new(100)
    stub_store.push(Struct.new(:id).new("dummy"))

    with_stub(RailsVitals, :store, stub_store) do
      with_stub(Aggregator, :aggregate, aggregate_result) do
        GetN1Queries.new.call(params)
      end
    end
  end

  # --- no data ---

  test "#call returns no-data response when store is empty" do
    with_stub(RailsVitals, :store, Store.new(100)) do
      result = GetN1Queries.new.call({})

      assert_equal 0, result[:total_patterns]
      assert_equal 0, result[:shown]
      assert_equal [], result[:patterns]
      assert_includes result[:message], "No requests recorded"
    end
  end

  test "#call returns no-n1 response when aggregator returns empty array" do
    result = call_tool(aggregate_result: [])

    assert_equal 0, result[:total_patterns]
    assert_equal 0, result[:shown]
    assert_equal [], result[:patterns]
    assert_includes result[:message], "No N+1 patterns"
  end

  # --- structure ---

  test "#call returns total_patterns and shown counts" do
    result = call_tool(aggregate_result: [ PATTERN_STUB, PATTERN_STUB_2 ])

    assert_equal 2, result[:total_patterns]
    assert_equal 2, result[:shown]
  end

  test "#call serializes pattern fields correctly" do
    result = call_tool(aggregate_result: [ PATTERN_STUB ])
    pattern = result[:patterns].first

    assert_equal PATTERN_STUB[:pattern], pattern[:pattern]
    assert_equal PATTERN_STUB[:occurrences], pattern[:occurrences]
    assert_equal PATTERN_STUB[:table], pattern[:table]
    assert_equal PATTERN_STUB[:foreign_key], pattern[:foreign_key]
  end

  test "#call serializes affected_endpoints sorted by request_count desc" do
    result = call_tool(aggregate_result: [ PATTERN_STUB ])
    endpoints = result[:patterns].first[:affected_endpoints]

    assert_equal 2, endpoints.size
    assert_equal "PostsController#index", endpoints.first[:endpoint]
    assert_equal 8, endpoints.first[:request_count]
    assert_equal "FeedController#show", endpoints.last[:endpoint]
    assert_equal 4, endpoints.last[:request_count]
  end

  test "#call serializes fix with code description owner and association" do
    result = call_tool(aggregate_result: [ PATTERN_STUB ])
    fix = result[:patterns].first[:fix]

    assert_equal "User.includes(:posts)",  fix[:code]
    assert_equal "Eager load :posts on User to eliminate this N+1", fix[:description]
    assert_equal "User", fix[:owner]
    assert_equal "posts", fix[:association]
  end

  # --- limit param ---

  test "#call respects limit param and sets shown accordingly" do
    result = call_tool(params: { limit: 1 }, aggregate_result: [ PATTERN_STUB, PATTERN_STUB_2 ])

    assert_equal 2, result[:total_patterns]
    assert_equal 1, result[:shown]
    assert_equal 1, result[:patterns].size
    assert_equal PATTERN_STUB[:pattern], result[:patterns].first[:pattern]
  end

  test "#call accepts string limit key from JSON params" do
    result = call_tool(params: { "limit" => 1 }, aggregate_result: [ PATTERN_STUB, PATTERN_STUB_2 ])

    assert_equal 1, result[:shown]
  end

  test "#call defaults to #{GetN1Queries::DEFAULT_LIMIT} patterns when limit is not given" do
    many = Array.new(15, PATTERN_STUB)
    result = call_tool(aggregate_result: many)

    assert_equal 15, result[:total_patterns]
    assert_equal GetN1Queries::DEFAULT_LIMIT, result[:shown]
    assert_equal GetN1Queries::DEFAULT_LIMIT, result[:patterns].size
  end

  # --- registration ---

  test "GetN1Queries is registered in ToolRegistry under its TOOL_NAME" do
    assert_equal GetN1Queries, RailsVitals::MCP::ToolRegistry.find(GetN1Queries::TOOL_NAME)
  end

  test ".definition includes name description and inputSchema with limit property" do
    defn = GetN1Queries.definition

    assert_equal GetN1Queries::TOOL_NAME, defn[:name]
    assert defn[:description].length > 10
    assert defn[:inputSchema][:properties].key?(:limit)
  end
end
