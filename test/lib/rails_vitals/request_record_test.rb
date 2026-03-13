require "test_helper"

class RailsVitalsRequestRecordTest < ActiveSupport::TestCase
  FakeScorer = Struct.new(:score, :label, :color, keyword_init: true)

  test "#initialize returns request record snapshot from collector fields and scorer output" do
    collector = RailsVitals::Collector.new
    collector.add_query(sql: "SELECT * FROM users", duration_ms: 10.0, source: "User")
    collector.add_callback(model: "User", kind: :before_save, duration_ms: 2.5)
    collector.finalize!(
      QueryEvent.new(
        payload: {
          controller: "UsersController",
          action: "index",
          method: "GET",
          status: 200
        },
        duration: 100.2
      )
    )

    scorer = FakeScorer.new(score: 91, label: "Healthy", color: "green")

    record = RailsVitals::RequestRecord.new(collector: collector, scorer: scorer)

    assert_match(/\A\h{16}\z/, record.id)
    assert_equal "UsersController", record.controller
    assert_equal "index", record.action
    assert_equal "GET", record.http_method
    assert_equal 200, record.response_status
    assert_equal 100.2, record.duration_ms
    assert_equal 91, record.score
    assert_equal "Healthy", record.label
    assert_equal "green", record.color
    assert_equal 1, record.queries.size
    assert_equal 1, record.callbacks.size
    assert_equal 2.5, record.total_callback_time_ms
    assert_kind_of Time, record.recorded_at
  end

  test "#endpoint returns String in Controller#action format" do
    collector = RailsVitals::Collector.new
    collector.finalize!(
      QueryEvent.new(
        payload: { controller: "PostsController", action: "show", method: "GET", status: 200 },
        duration: 20.0
      )
    )

    record = RailsVitals::RequestRecord.new(
      collector: collector,
      scorer: FakeScorer.new(score: 80, label: "Acceptable", color: "blue")
    )

    assert_equal "PostsController#show", record.endpoint
  end

  test "#total_query_count #total_db_time_ms and #slowest_queries return aggregated query data" do
    collector = RailsVitals::Collector.new
    collector.add_query(sql: "q1", duration_ms: 5.0, source: "A")
    collector.add_query(sql: "q2", duration_ms: 15.0, source: "B")
    collector.add_query(sql: "q3", duration_ms: 10.0, source: "C")

    record = RailsVitals::RequestRecord.new(
      collector: collector,
      scorer: FakeScorer.new(score: 75, label: "Acceptable", color: "blue")
    )

    assert_equal 3, record.total_query_count
    assert_equal 30.0, record.total_db_time_ms
    assert_equal [ "q2", "q3" ], record.slowest_queries(2).map { |query| query[:sql] }
  end

  test "#n_plus_one_patterns returns Hash<String, Integer> when scorer is CompositeScorer" do
    collector = RailsVitals::Collector.new
    3.times do |index|
      collector.add_query(
        sql: "SELECT * FROM users WHERE users.id = #{index + 1}",
        duration_ms: 3.0,
        source: "User"
      )
    end

    scorer = RailsVitals::Scorers::CompositeScorer.new(collector)
    record = RailsVitals::RequestRecord.new(collector: collector, scorer: scorer)

    assert_kind_of Hash, record.n_plus_one_patterns
    assert_equal 1, record.n_plus_one_patterns.size
    normalized_pattern = "select * from users where users.id = ?"
    assert_equal 3, record.n_plus_one_patterns[normalized_pattern]
  end

  test "#n_plus_one_patterns returns empty Hash when scorer is not CompositeScorer" do
    collector = RailsVitals::Collector.new
    scorer = FakeScorer.new(score: 100, label: "Healthy", color: "green")

    record = RailsVitals::RequestRecord.new(collector: collector, scorer: scorer)

    assert_equal({}, record.n_plus_one_patterns)
  end
end
