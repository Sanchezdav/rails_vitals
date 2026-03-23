require "test_helper"

class RailsVitalsExplainAnalyzerTest < ActiveSupport::TestCase
  Analyzer = RailsVitals::Analyzers::ExplainAnalyzer
  PlanNode = RailsVitals::Analyzers::ExplainAnalyzer::PlanNode
  Result   = RailsVitals::Analyzers::ExplainAnalyzer::Result

  # ─── substitute_binds ──────────────────────────────────────────────────────

  test ".substitute_binds replaces $1 and $2 positional placeholders with integer bind values" do
    sql    = "SELECT * FROM users WHERE id = $1 AND team_id = $2"
    result = Analyzer.send(:substitute_binds, sql, [ 42, 7 ])

    assert_equal "SELECT * FROM users WHERE id = 42 AND team_id = 7", result
  end

  test ".substitute_binds wraps string binds in single quotes and escapes embedded single quotes" do
    sql    = "SELECT * FROM users WHERE name = $1"
    result = Analyzer.send(:substitute_binds, sql, [ "O'Brien" ])

    assert_equal "SELECT * FROM users WHERE name = 'O''Brien'", result
  end

  test ".substitute_binds replaces remaining ? placeholders with NULL" do
    sql    = "SELECT * FROM users WHERE deleted_at = ?"
    result = Analyzer.send(:substitute_binds, sql, [])

    assert_equal "SELECT * FROM users WHERE deleted_at = NULL", result
  end

  # ─── analyze — guard clauses ───────────────────────────────────────────────

  test ".analyze returns Result with error when sql is not a SELECT statement" do
    result = Analyzer.analyze("INSERT INTO users (name) VALUES ('x')")

    assert_equal "EXPLAIN is only available for SELECT queries.", result.error
    assert_nil   result.plan
    assert_equal [], result.warnings
    assert_equal [], result.suggestions
  end

  test ".analyze returns Result with error for UPDATE sql" do
    result = Analyzer.analyze("UPDATE users SET name = 'x' WHERE id = 1")

    assert_equal "EXPLAIN is only available for SELECT queries.", result.error
  end

  test ".analyze returns Result with error when running in a non-supported environment" do
    with_stub(Rails, :env, "production") do
      result = Analyzer.analyze("SELECT * FROM users")

      assert_equal "EXPLAIN is only available in development and test environments.", result.error
      assert_nil result.plan
    end
  end

  # ─── analyze — DB rescue path ──────────────────────────────────────────────

  test ".analyze returns Result with error field populated when the database raises" do
    raising_conn = Object.new
    raising_conn.define_singleton_method(:execute) { |_sql| raise RuntimeError, "column does not exist" }

    with_stub(ActiveRecord::Base, :connection, raising_conn) do
      result = Analyzer.analyze("SELECT * FROM users")
      assert_equal "column does not exist", result.error
      assert_nil result.plan
    end
  end

  # ─── analyze — success path ─────────────────────────────────────────────────

  test ".analyze returns Result with PlanNode plan populated fields and no error when DB returns valid JSON plan" do
    plan_hash = {
      "Node Type"           => "Index Scan",
      "Total Cost"          => 1.5,
      "Startup Cost"        => 0.1,
      "Actual Startup Time" => 0.05,
      "Actual Total Time"   => 0.08,
      "Plan Rows"           => 1,
      "Actual Rows"         => 1,
      "Plan Width"          => 40,
      "Actual Loops"        => 1,
      "Index Name"          => "users_pkey",
      "Index Cond"          => "(id = 42)"
    }
    plan_doc  = [ { "Plan" => plan_hash, "Execution Time" => 0.2 } ].to_json
    fake_conn = Object.new
    fake_conn.define_singleton_method(:execute) { |*| [ { "QUERY PLAN" => plan_doc } ] }

    with_stub(ActiveRecord::Base, :connection, fake_conn) do
      result = Analyzer.analyze("SELECT * FROM users WHERE id = $1", binds: [ 42 ])

      assert_nil result.error
      assert_instance_of PlanNode, result.plan
      assert_equal 1.5,  result.total_cost
      assert_equal 0.2,  result.actual_time_ms
      assert_equal 1,    result.rows_examined
      assert_equal [],   result.warnings
      assert_equal [],   result.suggestions
      assert_includes result.sql, "42"
    end
  end

  # ─── build_node ────────────────────────────────────────────────────────────

  test ".build_node returns PlanNode with known metadata for Seq Scan node type" do
    plan = {
      "Node Type"                => "Seq Scan",
      "Relation Name"            => "orders",
      "Total Cost"               => 200.0,
      "Startup Cost"             => 0.0,
      "Plan Rows"                => 5000,
      "Actual Rows"              => 4800,
      "Rows Removed by Filter"   => 200,
      "Filter"                   => "(status = 'pending')",
      "Plan Width"               => 100,
      "Actual Loops"             => 1
    }
    node = Analyzer.send(:build_node, plan)

    assert_equal "Seq Scan",         node.node_type
    assert_equal "orders",           node.relation
    assert_equal 200.0,              node.total_cost
    assert_equal :danger,            node.metadata[:risk]
    assert_equal "#fc8181",          node.metadata[:color]
    assert_equal "Sequential Scan",  node.metadata[:label]
    assert_equal [],                 node.children
  end

  test ".build_node returns PlanNode with neutral fallback metadata for unknown node type" do
    plan = {
      "Node Type"  => "Custom Scan",
      "Total Cost" => 5.0,
      "Startup Cost" => 0.0,
      "Plan Rows"  => 10,
      "Actual Rows" => 10,
      "Plan Width" => 20,
      "Actual Loops" => 1
    }
    node = Analyzer.send(:build_node, plan)

    assert_equal "Custom Scan", node.node_type
    assert_equal :neutral,      node.metadata[:risk]
    assert_equal "#a0aec0",     node.metadata[:color]
    assert_equal "Custom Scan", node.metadata[:label]
    assert_nil   node.metadata[:explanation]
  end

  test ".build_node recursively builds children into Array<PlanNode>" do
    plan = {
      "Node Type"    => "Hash Join",
      "Total Cost"   => 50.0,
      "Startup Cost" => 0.0,
      "Plan Rows"    => 100,
      "Actual Rows"  => 95,
      "Plan Width"   => 60,
      "Actual Loops" => 1,
      "Plans"        => [
        {
          "Node Type"    => "Index Scan",
          "Total Cost"   => 10.0,
          "Startup Cost" => 0.0,
          "Plan Rows"    => 50,
          "Actual Rows"  => 50,
          "Plan Width"   => 30,
          "Actual Loops" => 1
        }
      ]
    }
    node = Analyzer.send(:build_node, plan)

    assert_equal 1,            node.children.size
    assert_equal "Index Scan", node.children.first.node_type
  end

  # ─── extract_warnings ──────────────────────────────────────────────────────

  test ".extract_warnings returns sequential_scan warning with table filter rows and severity for Seq Scan node" do
    node = PlanNode.new(
      node_type: "Seq Scan", relation: "users",
      actual_rows: 800, rows_removed_by_filter: 200,
      filter: "(user_id = 1)", children: [], plan_rows: 1000
    )
    warnings = Analyzer.send(:extract_warnings, node)

    assert_equal 1, warnings.size
    w = warnings.first
    assert_equal :sequential_scan, w[:type]
    assert_equal "users",          w[:table]
    assert_equal 800,              w[:rows]
    assert_equal 200,              w[:removed]
    assert_equal "(user_id = 1)",  w[:filter]
    assert_equal :danger,          w[:severity]
  end

  test ".extract_warnings returns sort_without_index warning for Sort node" do
    node = PlanNode.new(
      node_type: "Sort", relation: nil, actual_rows: 500, children: [], plan_rows: 500
    )
    warnings = Analyzer.send(:extract_warnings, node)

    assert_equal 1,                  warnings.size
    assert_equal :sort_without_index, warnings.first[:type]
    assert_equal :warning,            warnings.first[:severity]
  end

  test ".extract_warnings returns no large_nested_loop warning when actual_rows is at or below 1000" do
    node = PlanNode.new(
      node_type: "Nested Loop", actual_rows: 1000, children: [], plan_rows: 1000
    )
    assert_equal [], Analyzer.send(:extract_warnings, node)
  end

  test ".extract_warnings returns large_nested_loop warning when actual_rows exceeds 1000" do
    node = PlanNode.new(
      node_type: "Nested Loop", actual_rows: 1001, children: [], plan_rows: 2000
    )
    warnings = Analyzer.send(:extract_warnings, node)

    assert_equal 1,                  warnings.size
    assert_equal :large_nested_loop, warnings.first[:type]
    assert_equal 1001,               warnings.first[:rows]
    assert_equal :warning,           warnings.first[:severity]
  end

  test ".extract_warnings recursively collects warnings from child nodes" do
    child = PlanNode.new(
      node_type: "Seq Scan", relation: "posts",
      actual_rows: 5000, rows_removed_by_filter: 0,
      filter: nil, children: [], plan_rows: 5000
    )
    parent = PlanNode.new(
      node_type: "Hash Join", actual_rows: 500, children: [ child ], plan_rows: 500
    )
    warnings = Analyzer.send(:extract_warnings, parent)

    assert_equal 1,                warnings.size
    assert_equal :sequential_scan, warnings.first[:type]
    assert_equal "posts",          warnings.first[:table]
  end

  # ─── count_rows_examined ───────────────────────────────────────────────────

  test ".count_rows_examined returns sum of Actual Rows and Rows Removed by Filter for leaf node" do
    plan = { "Actual Rows" => 800, "Rows Removed by Filter" => 200 }
    assert_equal 1000, Analyzer.send(:count_rows_examined, plan)
  end

  test ".count_rows_examined sums children recursively and ignores intermediate node own row count" do
    plan = {
      "Actual Rows" => 9999,
      "Plans" => [
        { "Actual Rows" => 300, "Rows Removed by Filter" => 100 },
        { "Actual Rows" => 50,  "Rows Removed by Filter" => 0   }
      ]
    }
    assert_equal 450, Analyzer.send(:count_rows_examined, plan)
  end

  # ─── build_suggestions ─────────────────────────────────────────────────────

  test ".build_suggestions returns Array<Hash> with danger suggestion and FK-based migration for sequential_scan warning with FK in filter" do
    warnings  = [
      { type: :sequential_scan, table: "orders", filter: "(user_id = 42)",
        rows: 4800, removed: 200, severity: :danger }
    ]
    root_node = PlanNode.new(node_type: "Seq Scan", children: [])
    suggestions = Analyzer.send(:build_suggestions, warnings, root_node)

    assert_equal 1, suggestions.size
    s = suggestions.first
    assert_equal :danger,                         s[:severity]
    assert_includes s[:title],                   "orders"
    assert_includes s[:title],                   "user_id"
    assert_equal    "add_index :orders, :user_id", s[:migration]
    assert_includes s[:command],                 "migration"
  end

  test ".build_suggestions returns migration with COLUMN_NAME placeholder when sequential_scan filter has no detectable FK" do
    warnings  = [
      { type: :sequential_scan, table: "events", filter: nil,
        rows: 100, removed: 0, severity: :danger }
    ]
    root_node = PlanNode.new(node_type: "Seq Scan", children: [])
    suggestions = Analyzer.send(:build_suggestions, warnings, root_node)

    assert_equal "add_index :events, :COLUMN_NAME", suggestions.first[:migration]
  end

  test ".build_suggestions returns Array<Hash> with warning suggestion for sort_without_index with nil command" do
    warnings  = [ { type: :sort_without_index, table: "users", severity: :warning } ]
    root_node = PlanNode.new(node_type: "Sort", children: [])
    suggestions = Analyzer.send(:build_suggestions, warnings, root_node)

    assert_equal 1, suggestions.size
    s = suggestions.first
    assert_equal :warning,                              s[:severity]
    assert_equal "add_index :users, :SORT_COLUMN",      s[:migration]
    assert_nil   s[:command]
  end

  test ".build_suggestions returns Array<Hash> with warning suggestion for large_nested_loop with nil migration and command" do
    warnings  = [ { type: :large_nested_loop, rows: 3000, severity: :warning } ]
    root_node = PlanNode.new(node_type: "Nested Loop", children: [])
    suggestions = Analyzer.send(:build_suggestions, warnings, root_node)

    assert_equal 1,        suggestions.size
    assert_equal :warning, suggestions.first[:severity]
    assert_nil   suggestions.first[:migration]
    assert_nil   suggestions.first[:command]
  end

  # ─── interpret ─────────────────────────────────────────────────────────────

  test ".interpret returns nil when result has an error" do
    result = Result.new(error: "something failed", warnings: [], plan: nil)
    assert_nil Analyzer.send(:interpret, result)
  end

  test ".interpret returns healthy message when there are no warnings and query is fast" do
    plan   = PlanNode.new(node_type: "Index Scan", plan_width: 50, children: [])
    result = Result.new(error: nil, warnings: [], actual_time_ms: 5.0, plan: plan)
    assert_equal "Plan looks healthy — index used, no warnings.", Analyzer.send(:interpret, result)
  end

  test ".interpret includes sequential scan text when sequential_scan warning is present" do
    plan   = PlanNode.new(node_type: "Seq Scan", plan_width: 80, children: [])
    result = Result.new(
      error: nil,
      warnings: [ { type: :sequential_scan } ],
      actual_time_ms: 5.0,
      plan: plan
    )
    assert_includes Analyzer.send(:interpret, result), "Sequential scan detected"
  end

  test ".interpret includes time warning when actual_time_ms exceeds 100ms threshold" do
    plan   = PlanNode.new(node_type: "Index Scan", plan_width: 50, children: [])
    result = Result.new(error: nil, warnings: [], actual_time_ms: 120.5, plan: plan)
    msg    = Analyzer.send(:interpret, result)

    assert_includes msg, "120.5ms"
    assert_includes msg, "100ms warning threshold"
  end

  test ".interpret includes row width warning when plan_width exceeds 200 bytes" do
    plan   = PlanNode.new(node_type: "Index Scan", plan_width: 250, children: [])
    result = Result.new(error: nil, warnings: [], actual_time_ms: 5.0, plan: plan)
    msg    = Analyzer.send(:interpret, result)

    assert_includes msg, "250B"
    assert_includes msg, ".select(:col)"
  end
end
