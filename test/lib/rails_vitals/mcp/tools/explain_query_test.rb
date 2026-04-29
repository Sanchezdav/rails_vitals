require "test_helper"
require "rails_vitals/mcp/tools/base"
require "rails_vitals/mcp/tool_registry"
require "rails_vitals/mcp/tools/explain_query"

class RailsVitalsMCPToolsExplainQueryTest < ActiveSupport::TestCase
  ExplainQuery = RailsVitals::MCP::Tools::ExplainQuery
  ExplainAnalyzer = RailsVitals::Analyzers::ExplainAnalyzer

  SELECT_SQL = "SELECT * FROM posts WHERE user_id = 1"

  def make_result(overrides = {})
    ExplainAnalyzer::Result.new(
      sql: SELECT_SQL,
      plan: nil,
      total_cost: 42.5,
      actual_time_ms: 18.3,
      rows_examined: 1000,
      warnings: [],
      suggestions: [],
      interpretation: "Plan looks healthy — index used, no warnings.",
      error: nil,
      **overrides
    )
  end

  def make_dry_run_result(overrides = {})
    ExplainAnalyzer::Result.new(
      sql: SELECT_SQL,
      plan: nil,
      total_cost: 42.5,
      error: nil,
      **overrides
    )
  end

  def call_tool(params)
    with_stub(ExplainAnalyzer, :dry_run, make_dry_run_result) do
      with_stub(ExplainAnalyzer, :analyze, make_result) do
        ExplainQuery.new.call(params)
      end
    end
  end

  def with_stubbed_explain(analyze_return, dry_run_return: nil)
    dry_run_return ||= make_dry_run_result
    with_stub(ExplainAnalyzer, :dry_run, dry_run_return) do
      with_stub(ExplainAnalyzer, :analyze, analyze_return) do
        yield
      end
    end
  end

  # --- missing sql ---

  test "#call returns error when sql param is missing" do
    result = ExplainQuery.new.call({})

    assert result[:error]
    assert_includes result[:error], "Missing required parameter"
  end

  test "#call returns error when sql param is empty string" do
    result = ExplainQuery.new.call({ sql: "   " })

    assert result[:error]
    assert_includes result[:error], "Missing required parameter"
  end

  test "#call accepts string sql key from JSON params" do
    with_stubbed_explain(make_result) do
      result = ExplainQuery.new.call({ "sql" => SELECT_SQL })

      assert_nil result[:error]
    end
  end

  # --- DML guard ---

  test "#call rejects INSERT statements" do
    result = ExplainQuery.new.call({ sql: "INSERT INTO posts (title) VALUES ('x')" })

    assert result[:error]
    assert_includes result[:error], "INSERT"
  end

  test "#call rejects UPDATE statements" do
    result = ExplainQuery.new.call({ sql: "UPDATE posts SET title = 'x' WHERE id = 1" })

    assert result[:error]
    assert_includes result[:error], "UPDATE"
  end

  test "#call rejects DELETE statements" do
    result = ExplainQuery.new.call({ sql: "DELETE FROM posts WHERE id = 1" })

    assert result[:error]
    assert_includes result[:error], "DELETE"
  end

  test "#call rejects DROP statements" do
    result = ExplainQuery.new.call({ sql: "DROP TABLE posts" })

    assert result[:error]
    assert_includes result[:error], "DROP"
  end

  test "#call rejects TRUNCATE statements" do
    result = ExplainQuery.new.call({ sql: "TRUNCATE posts" })

    assert result[:error]
    assert_includes result[:error], "TRUNCATE"
  end

  test "#call rejects ALTER statements" do
    result = ExplainQuery.new.call({ sql: "ALTER TABLE posts ADD COLUMN body text" })

    assert result[:error]
    assert_includes result[:error], "ALTER"
  end

  test "#call rejects DML inside CTEs" do
    cte_sql = "WITH d AS (DELETE FROM posts WHERE id = 1) SELECT * FROM d"
    result = ExplainQuery.new.call({ sql: cte_sql })

    assert result[:error]
    assert_includes result[:error], "DELETE"
  end

  test "#call does not reject SELECT with columns named like DML keywords" do
    sql = "SELECT id, updated_at, created_at FROM posts WHERE user_id = 1"
    with_stubbed_explain(make_result) do
      result = ExplainQuery.new.call({ sql: sql })

      assert_nil result[:error]
    end
  end

  # --- analyzer errors ---

  test "#call returns error response when ExplainAnalyzer returns an error" do
    error_result = make_result(error: "EXPLAIN is only available for SELECT queries.")
    with_stubbed_explain(error_result) do
      result = ExplainQuery.new.call({ sql: SELECT_SQL })

      assert result[:error]
      assert_includes result[:error], "SELECT"
    end
  end

  # --- serialization ---

  test "#call serializes top-level fields" do
    result = call_tool({ sql: SELECT_SQL })

    assert_equal SELECT_SQL, result[:sql]
    assert_equal 42.5, result[:total_cost]
    assert_equal 18.3, result[:actual_time_ms]
    assert_equal 1000, result[:rows_examined]
    assert_equal "Plan looks healthy — index used, no warnings.", result[:interpretation]
  end

  test "#call serializes cost estimate" do
    result = call_tool({ sql: SELECT_SQL })

    assert result[:cost_estimate]
    assert_equal 42.5, result[:cost_estimate][:total_cost]
  end

  test "#call serializes function_calls field" do
    result = call_tool({ sql: SELECT_SQL })

    assert_includes result.keys, :function_calls
  end

  test "#call serializes warnings with type severity and table" do
    warnings = [
      { type: :sequential_scan, severity: :danger, table: "posts", rows: 5000, removed: 4900 }
    ]
    with_stubbed_explain(make_result(warnings: warnings)) do
      result = ExplainQuery.new.call({ sql: SELECT_SQL })
      w = result[:warnings].first

      assert_equal "sequential_scan", w[:type]
      assert_equal "danger", w[:severity]
      assert_equal "posts", w[:table]
      assert_equal 5000, w[:rows_scanned]
    end
  end

  test "#call serializes suggestions with severity title body and migration" do
    suggestions = [
      { severity: :danger, title: "Add index on posts.user_id",
        body: "Full table scan detected.", migration: "add_index :posts, :user_id",
        command: "rails g migration AddUserIdIndexToPosts" }
    ]
    with_stubbed_explain(make_result(suggestions: suggestions)) do
      result = ExplainQuery.new.call({ sql: SELECT_SQL })
      s = result[:suggestions].first

      assert_equal "danger", s[:severity]
      assert_equal "Add index on posts.user_id", s[:title]
      assert_equal "Full table scan detected.", s[:body]
      assert_equal "add_index :posts, :user_id", s[:migration]
      assert_equal "rails g migration AddUserIdIndexToPosts", s[:command]
    end
  end

  test "#call omits nil migration and command from suggestions" do
    suggestions = [
      { severity: :warning, title: "Large Nested Loop",
        body: "Check join indexes.", migration: nil, command: nil }
    ]
    with_stubbed_explain(make_result(suggestions: suggestions)) do
      result = ExplainQuery.new.call({ sql: SELECT_SQL })
      s = result[:suggestions].first

      refute s.key?(:migration)
      refute s.key?(:command)
    end
  end

  test "#call returns empty arrays for warnings and suggestions when plan is clean" do
    result = call_tool({ sql: SELECT_SQL })

    assert_equal [], result[:warnings]
    assert_equal [], result[:suggestions]
  end

  test "#call returns cost estimate with note when dry run succeeded" do
    result = call_tool({ sql: SELECT_SQL })

    assert result[:cost_estimate][:note]
    assert_includes result[:cost_estimate][:note], "ANALYZE was not executed"
  end

  # --- dry_run error ---

  test "#call returns error when dry_run fails" do
    failed_dry_run = make_dry_run_result(error: "column does not exist")
    with_stub(ExplainAnalyzer, :dry_run, failed_dry_run) do
      result = ExplainQuery.new.call({ sql: SELECT_SQL })

      assert result[:error]
      assert_includes result[:error], "Cost estimate failed"
      assert_includes result[:error], "column does not exist"
    end
  end

  # --- registration ---

  test "ExplainQuery is registered in ToolRegistry under its TOOL_NAME" do
    assert_equal ExplainQuery, RailsVitals::MCP::ToolRegistry.find(ExplainQuery::TOOL_NAME)
  end

  test ".definition includes name description and inputSchema with required sql" do
    defn = ExplainQuery.definition

    assert_equal ExplainQuery::TOOL_NAME, defn[:name]
    assert defn[:description].length > 10
    assert defn[:inputSchema][:properties].key?(:sql)
    assert_includes defn[:inputSchema][:required], "sql"
  end
end
