require "test_helper"
require "rails_vitals/mcp/tools/base"
require "rails_vitals/mcp/tool_registry"
require "rails_vitals/mcp/tools/get_score"

class RailsVitalsMCPToolsGetScoreTest < ActiveSupport::TestCase
  GetScore = RailsVitals::MCP::Tools::GetScore
  Store = RailsVitals::Store
  BaseScorer = RailsVitals::Scorers::BaseScorer

  RecordDouble = Struct.new(
    :score,
    :n_plus_one_patterns,
    :total_query_count,
    :total_db_time_ms,
    keyword_init: true
  )

  def build_record(score:, n1_patterns: {}, query_count: 5, db_time_ms: 20.0)
    RecordDouble.new(
      score: score,
      n_plus_one_patterns: n1_patterns,
      total_query_count: query_count,
      total_db_time_ms: db_time_ms
    )
  end

  def call_tool(store_records)
    with_stub(RailsVitals, :store, Store.new(100)) do
      store_records.each { |r| RailsVitals.store.push(r) }
      GetScore.new.call({})
    end
  end

  # --- no data ---

  test "#call returns no-data response when store is empty" do
    result = call_tool([])

    assert_nil result[:overall_score]
    assert_equal "No data", result[:grade]
    assert_equal "grey", result[:color]
    assert_equal 0, result[:requests_analyzed]
    assert result[:message].include?("No requests")
  end

  # --- overall score and grade ---

  test "#call returns overall_score averaged from all records" do
    records = [
      build_record(score: 80),
      build_record(score: 60)
    ]

    result = call_tool(records)

    assert_equal 70.0, result[:overall_score]
  end

  test "#call returns grade Healthy for score >= 90" do
    result = call_tool([ build_record(score: 95) ])

    assert_equal "Healthy", result[:grade]
    assert_equal "green", result[:color]
  end

  test "#call returns grade Acceptable for score in 70..89" do
    result = call_tool([ build_record(score: 80) ])

    assert_equal "Acceptable", result[:grade]
    assert_equal "blue", result[:color]
  end

  test "#call returns grade Warning for score in 50..69" do
    result = call_tool([ build_record(score: 60) ])

    assert_equal "Warning", result[:grade]
    assert_equal "amber", result[:color]
  end

  test "#call returns grade Critical for score < 50" do
    result = call_tool([ build_record(score: 30) ])

    assert_equal "Critical", result[:grade]
    assert_equal "red", result[:color]
  end

  test "#call includes requests_analyzed count" do
    records = Array.new(3) { build_record(score: 90) }
    result  = call_tool(records)

    assert_equal 3, result[:requests_analyzed]
  end

  # --- score_breakdown ---

  test "#call returns score_breakdown with query and n1 components" do
    result = call_tool([ build_record(score: 100) ])

    breakdown = result[:score_breakdown]

    assert_equal 0.40, breakdown[:query_component][:weight]
    assert_equal 0.60, breakdown[:n1_component][:weight]
    assert_kind_of Numeric, breakdown[:query_component][:avg_score]
    assert_kind_of Numeric, breakdown[:n1_component][:avg_score]
    assert_kind_of Numeric, breakdown[:query_component][:avg_contribution]
    assert_kind_of Numeric, breakdown[:n1_component][:avg_contribution]
  end

  test "#call derives n1_score 100 for a record with no N+1 patterns" do
    record = build_record(score: 100, n1_patterns: {})
    result = call_tool([ record ])

    assert_equal 100.0, result[:score_breakdown][:n1_component][:avg_score]
  end

  test "#call derives n1_score 75 for a record with one N+1 pattern" do
    record = build_record(score: 75, n1_patterns: { "SELECT ..." => 3 })
    result = call_tool([ record ])

    assert_equal 75.0, result[:score_breakdown][:n1_component][:avg_score]
  end

  test "#call clamps n1_score to 0 for records with 4 or more N+1 patterns" do
    patterns = { "a" => 3, "b" => 3, "c" => 3, "d" => 3 }
    record = build_record(score: 20, n1_patterns: patterns)
    result = call_tool([ record ])

    assert_equal 0.0, result[:score_breakdown][:n1_component][:avg_score]
  end

  # --- penalties ---

  test "#call penalties.n1_patterns reflects affected request count and total patterns" do
    clean = build_record(score: 100, n1_patterns: {})
    bad = build_record(score: 50,  n1_patterns: { "SELECT ..." => 3, "INSERT ..." => 3 })
    result = call_tool([ clean, bad ])

    n1 = result[:penalties][:n1_patterns]
    assert_equal 1, n1[:requests_affected]
    assert_equal 50.0, n1[:percentage_requests]
    assert_equal 2, n1[:unique_patterns]
    assert_equal 2, n1[:total_occurrences]
  end

  test "#call penalties.high_query_count counts requests exceeding warn threshold" do
    with_rails_vitals_config(query_warn_threshold: 10) do
      low = build_record(score: 100, query_count: 5)
      high = build_record(score: 60,  query_count: 15)
      result = call_tool([ low, high ])

      penalty = result[:penalties][:high_query_count]
      assert_equal 1, penalty[:requests_above_threshold]
      assert_equal 10, penalty[:threshold]
    end
  end

  test "#call penalties.slow_db_time counts requests exceeding db warn threshold" do
    with_rails_vitals_config(db_time_warn_ms: 100) do
      fast = build_record(score: 100, db_time_ms: 40.0)
      slow = build_record(score: 60,  db_time_ms: 250.0)
      result = call_tool([ fast, slow ])

      penalty = result[:penalties][:slow_db_time]
      assert_equal 1, penalty[:requests_above_threshold]
      assert_equal 100, penalty[:threshold_ms]
    end
  end

  # --- projected_score_if_n1_fixed ---

  test "#call projected_score_if_n1_fixed equals overall_score when no N+1 patterns exist" do
    record = build_record(score: 80, n1_patterns: {})
    result = call_tool([ record ])

    assert_equal result[:overall_score].round, result[:projected_score_if_n1_fixed]
  end

  test "#call projected_score_if_n1_fixed is higher than overall_score when N+1 patterns exist" do
    record = build_record(score: 50, n1_patterns: { "SELECT ..." => 3 })
    result = call_tool([ record ])

    assert result[:projected_score_if_n1_fixed] > result[:overall_score],
           "Expected projected (#{result[:projected_score_if_n1_fixed]}) > overall (#{result[:overall_score]})"
  end

  test "#call projected_score_if_n1_fixed is clamped to 100" do
    record = build_record(score: 100, n1_patterns: {})
    result = call_tool([ record ])

    assert result[:projected_score_if_n1_fixed] <= 100
  end

  # --- tool registration ---

  test "GetScore is registered in ToolRegistry under its TOOL_NAME" do
    assert_equal GetScore, RailsVitals::MCP::ToolRegistry.find(GetScore::TOOL_NAME)
  end

  test ".definition includes expected keys" do
    defn = GetScore.definition
    assert_equal GetScore::TOOL_NAME, defn[:name]
    assert defn[:description].length > 10
    assert_equal "object", defn[:inputSchema][:type]
  end
end
