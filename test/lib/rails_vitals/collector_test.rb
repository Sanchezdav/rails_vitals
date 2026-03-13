require "test_helper"

class RailsVitalsCollectorTest < ActiveSupport::TestCase
  test "#add_query returns query Hash with keys :sql, :duration_ms, :source, :called_at" do
    collector = RailsVitals::Collector.new

    result = collector.add_query(sql: "SELECT 1", duration_ms: 12.3, source: "app/models/user.rb")

    assert_equal collector.queries, result
    assert_equal 1, result.size
    assert_equal "SELECT 1", result.first[:sql]
    assert_equal 12.3, result.first[:duration_ms]
    assert_equal "app/models/user.rb", result.first[:source]
    assert_kind_of Time, result.first[:called_at]
  end

  test "#finalize! returns collector fields mapped from controller event payload" do
    collector = RailsVitals::Collector.new
    event = QueryEvent.new(
      payload: {
        controller: "UsersController",
        action: "index",
        method: "GET",
        status: 200
      },
      duration: 45.6
    )

    collector.finalize!(event)

    assert_equal "UsersController", collector.controller
    assert_equal "index", collector.action
    assert_equal "GET", collector.http_method
    assert_equal 200, collector.response_status
    assert_equal 45.6, collector.duration_ms
  end

  test "#total_query_count and #total_db_time_ms return Integer and summed Numeric values" do
    collector = RailsVitals::Collector.new
    collector.add_query(sql: "SELECT * FROM users", duration_ms: 12.5, source: "User")
    collector.add_query(sql: "SELECT * FROM posts", duration_ms: 7.5, source: "Post")

    assert_equal 2, collector.total_query_count
    assert_equal 20.0, collector.total_db_time_ms
  end

  test "#slowest_queries returns Array<Hash> sorted by duration desc and respecting limit" do
    collector = RailsVitals::Collector.new
    collector.add_query(sql: "q1", duration_ms: 5.0, source: "A")
    collector.add_query(sql: "q2", duration_ms: 25.0, source: "B")
    collector.add_query(sql: "q3", duration_ms: 15.0, source: "C")

    result = collector.slowest_queries(2)

    assert_equal 2, result.size
    assert_equal [ "q2", "q3" ], result.map { |query| query[:sql] }
  end

  test "#add_callback and #callbacks_by_model return grouped callback hashes and summed callback time" do
    collector = RailsVitals::Collector.new
    collector.add_callback(model: "User", kind: :before_save, duration_ms: 3.2)
    collector.add_callback(model: "User", kind: :after_commit, duration_ms: 1.8)
    collector.add_callback(model: "Post", kind: :before_validation, duration_ms: 2.0)

    grouped = collector.callbacks_by_model

    assert_equal [ "Post", "User" ], grouped.keys.sort
    assert_equal 2, grouped["User"].size
    assert_equal 1, grouped["Post"].size
    assert_equal 7.0, collector.total_callback_time_ms
  end

  test ".current and .reset! return assigned collector and nil after reset" do
    collector = RailsVitals::Collector.new

    RailsVitals::Collector.current = collector
    assert_equal collector, RailsVitals::Collector.current

    RailsVitals::Collector.reset!
    assert_nil RailsVitals::Collector.current
  end
end
