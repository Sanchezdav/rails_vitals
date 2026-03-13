require "test_helper"

class RailsVitalsPanelInjectorTest < ActiveSupport::TestCase
  test "#call returns original Rack response without panel when response is not HTML" do
    app = ->(_env) { [ 200, { "Content-Type" => "application/json" }, [ '{"ok":true}' ] ] }
    middleware = RailsVitals::Middleware::PanelInjector.new(app)

    status, headers, body = middleware.call({ "PATH_INFO" => "/", "SCRIPT_NAME" => "" })

    assert_equal 200, status
    assert_equal "application/json", headers["Content-Type"]
    assert_equal [ '{"ok":true}' ], body
    assert_nil RailsVitals::Collector.current
  end

  test "#call returns HTML response with injected panel before </body> and updated Content-Length" do
    app = ->(_env) { [ 200, { "Content-Type" => "text/html", "Content-Length" => "26" }, [ "<html><body>Hello</body></html>" ] ] }
    middleware = RailsVitals::Middleware::PanelInjector.new(app)
    scorer = Struct.new(:score, :label, :color).new(80, "Acceptable", "blue")
    record = Struct.new(:id).new("req_123")

    with_stub(RailsVitals::Scorers::CompositeScorer, :new, scorer) do
      with_stub(RailsVitals::RequestRecord, :new, record) do
        with_stub(RailsVitals::PanelRenderer, :render, "<div id='panel'>panel</div>") do
          with_rails_vitals_config(store_enabled: true) do
            status, headers, body = middleware.call({ "PATH_INFO" => "/users", "SCRIPT_NAME" => "" })

            assert_equal 200, status
            assert_includes body.first, "<div id='panel'>panel</div></body>"
            assert_equal body.first.bytesize.to_s, headers["Content-Length"]
          end
        end
      end
    end

    assert_nil RailsVitals::Collector.current
  end

  test "#call returns response without panel injection for rails_vitals engine request path" do
    app = ->(_env) { [ 200, { "Content-Type" => "text/html" }, [ "<html><body>Vitals</body></html>" ] ] }
    middleware = RailsVitals::Middleware::PanelInjector.new(app)

    status, _headers, body = middleware.call({ "PATH_INFO" => "/rails_vitals", "SCRIPT_NAME" => "/rails_vitals" })

    assert_equal 200, status
    assert_equal "<html><body>Vitals</body></html>", body.first
    assert_nil RailsVitals::Collector.current
  end
end
