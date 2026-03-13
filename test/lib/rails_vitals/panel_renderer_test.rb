require "test_helper"

class RailsVitalsPanelRendererTest < ActiveSupport::TestCase
  ScorerDouble = Struct.new(:score, :label, :color, keyword_init: true)

  test ".render returns HTML String containing score label endpoint summary and admin report link" do
    collector = build_collector(
      queries: [ build_query(sql: "SELECT * FROM users WHERE users.id = 1", duration_ms: 12.3) ],
      callbacks: [ { model: "User", kind: :save, duration_ms: 1.2, called_at: Time.current } ]
    )
    collector.finalize!(
      QueryEvent.new(
        payload: { controller: "UsersController", action: "show", method: "GET", status: 200 },
        duration: 44.4
      )
    )
    scorer = ScorerDouble.new(score: 86, label: "Acceptable", color: "blue")
    latest_record = Struct.new(:id).new("req_abc")
    store_double = Struct.new(:all).new([ latest_record ])

    with_stub(RailsVitals, :store, store_double) do
      html = RailsVitals::PanelRenderer.render(collector, scorer)

      assert_kind_of String, html
      assert_includes html, "rails-vitals-panel"
      assert_includes html, "86"
      assert_includes html, "Acceptable"
      assert_includes html, "UsersController#show"
      assert_includes html, "/rails_vitals/requests/req_abc"
    end
  end

  test ".render returns escaped query text and omits slowest section when query list is empty" do
    collector = build_collector
    collector.finalize!(
      QueryEvent.new(
        payload: { controller: "UsersController", action: "index", method: "GET", status: 200 },
        duration: 12.0
      )
    )
    scorer = ScorerDouble.new(score: 100, label: "Healthy", color: "green")
    store_double = Struct.new(:all).new([])

    with_stub(RailsVitals, :store, store_double) do
      html = RailsVitals::PanelRenderer.render(collector, scorer)

      assert_includes html, "None"
      refute_includes html, "Slowest Queries"
    end
  end
end
