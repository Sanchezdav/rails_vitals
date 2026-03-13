require "test_helper"

class RailsVitalsQueryScorerTest < ActiveSupport::TestCase
  CollectorDouble = Struct.new(:total_query_count, :total_db_time_ms, keyword_init: true)

  test "#score returns 100 when query count and db time are at or below warn thresholds" do
    with_rails_vitals_config(
      query_warn_threshold: 10,
      query_critical_threshold: 25,
      db_time_warn_ms: 100,
      db_time_critical_ms: 500
    ) do
      collector = CollectorDouble.new(total_query_count: 10, total_db_time_ms: 100)
      scorer = RailsVitals::Scorers::QueryScorer.new(collector)

      assert_equal 100, scorer.score
    end
  end

  test "#score returns interpolated Integer when values are between warn and critical thresholds" do
    with_rails_vitals_config(
      query_warn_threshold: 10,
      query_critical_threshold: 25,
      db_time_warn_ms: 100,
      db_time_critical_ms: 500
    ) do
      collector = CollectorDouble.new(total_query_count: 17, total_db_time_ms: 300)
      scorer = RailsVitals::Scorers::QueryScorer.new(collector)

      assert_equal 52, scorer.score
    end
  end

  test "#score returns 0 when query count and db time exceed critical thresholds" do
    with_rails_vitals_config(
      query_warn_threshold: 10,
      query_critical_threshold: 25,
      db_time_warn_ms: 100,
      db_time_critical_ms: 500
    ) do
      collector = CollectorDouble.new(total_query_count: 30, total_db_time_ms: 800)
      scorer = RailsVitals::Scorers::QueryScorer.new(collector)

      assert_equal 0, scorer.score
    end
  end

  test "#score returns configured result when custom threshold values are set" do
    with_rails_vitals_config(
      query_warn_threshold: 5,
      query_critical_threshold: 15,
      db_time_warn_ms: 50,
      db_time_critical_ms: 150
    ) do
      collector = CollectorDouble.new(total_query_count: 5, total_db_time_ms: 150)
      scorer = RailsVitals::Scorers::QueryScorer.new(collector)

      assert_equal 50, scorer.score
    end
  end
end
