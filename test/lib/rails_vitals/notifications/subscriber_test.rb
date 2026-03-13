require "test_helper"

class RailsVitalsSubscriberTest < ActiveSupport::TestCase
  test ".attach_sql_subscriber returns collector query capture for non-internal SQL when enabled" do
    collector = RailsVitals::Collector.new
    RailsVitals::Collector.current = collector
    block = capture_subscriber_block(:attach_sql_subscriber)

    with_rails_vitals_config(enabled: true) do
      block.call(QueryEvent.new(payload: { sql: "SELECT * FROM users", binds: [] }, duration: 12.4))
    end

    assert_equal 1, collector.queries.size
    assert_equal "SELECT * FROM users", collector.queries.first[:sql]
    assert_equal 12.4, collector.queries.first[:duration_ms]
  ensure
    RailsVitals::Collector.reset!
  end

  test ".attach_sql_subscriber returns unchanged collector query list when SQL is internal" do
    collector = RailsVitals::Collector.new
    RailsVitals::Collector.current = collector
    block = capture_subscriber_block(:attach_sql_subscriber)

    with_rails_vitals_config(enabled: true) do
      block.call(QueryEvent.new(payload: { sql: "SCHEMA", binds: [] }, duration: 5.0))
    end

    assert_equal [], collector.queries
  ensure
    RailsVitals::Collector.reset!
  end

  test ".attach_sql_subscriber returns no query capture when current request is RailsVitals own request" do
    collector = RailsVitals::Collector.new
    RailsVitals::Collector.current = collector
    Thread.current[:rails_vitals_own_request] = true
    block = capture_subscriber_block(:attach_sql_subscriber)

    with_rails_vitals_config(enabled: true) do
      block.call(QueryEvent.new(payload: { sql: "SELECT * FROM users", binds: [] }, duration: 5.0))
    end

    assert_equal [], collector.queries
  ensure
    Thread.current[:rails_vitals_own_request] = nil
    RailsVitals::Collector.reset!
  end

  test ".attach_action_controller_subscriber returns finalized collector fields for non-engine controller" do
    collector = RailsVitals::Collector.new
    RailsVitals::Collector.current = collector
    block = capture_subscriber_block(:attach_action_controller_subscriber)

    with_rails_vitals_config(enabled: true) do
      block.call(
        QueryEvent.new(
          payload: { controller: "UsersController", action: "index", method: "GET", status: 200 },
          duration: 45.2
        )
      )
    end

    assert_equal "UsersController", collector.controller
    assert_equal "index", collector.action
    assert_equal "GET", collector.http_method
    assert_equal 200, collector.response_status
    assert_equal 45.2, collector.duration_ms
  ensure
    RailsVitals::Collector.reset!
  end

  test ".attach_action_controller_subscriber returns unchanged collector fields for engine controller events" do
    collector = RailsVitals::Collector.new
    RailsVitals::Collector.current = collector
    block = capture_subscriber_block(:attach_action_controller_subscriber)

    with_rails_vitals_config(enabled: true) do
      block.call(
        QueryEvent.new(
          payload: { controller: "RailsVitals::DashboardController", action: "index", method: "GET", status: 200 },
          duration: 45.2
        )
      )
    end

    assert_nil collector.controller
    assert_nil collector.action
  ensure
    RailsVitals::Collector.reset!
  end

  private

  def capture_subscriber_block(method_name)
    subscriber_block = nil

    with_stub(ActiveSupport::Notifications, :subscribe, ->(_name, &blk) { subscriber_block = blk }) do
      RailsVitals::Notifications::Subscriber.send(method_name)
    end

    subscriber_block
  end
end
