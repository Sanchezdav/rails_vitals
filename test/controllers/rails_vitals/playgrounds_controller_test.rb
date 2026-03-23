require "test_helper"

class RailsVitalsPlaygroundsControllerTest < ActionDispatch::IntegrationTest
  ModelDouble = Struct.new(:name)
  StoreDouble = Struct.new(:all)

  test "GET /rails_vitals/playgrounds renders playground page with form and run button" do
    with_stub(RailsVitals, :store, StoreDouble.new([])) do
      with_stub(RailsVitals::Analyzers::AssociationMapper, :discover_models, [ ModelDouble.new("User") ]) do
        with_stub(RailsVitals::Playground::Sandbox, :associations_for, [ "posts", "comments" ]) do
          get "/rails_vitals/playgrounds"

          assert_response :success
          assert_includes response.body, "N+1 Fix Playground"
          assert_includes response.body, 'id="playground-form"'
          assert_includes response.body, 'id="run-btn"'
          assert_includes response.body, ":posts"
        end
      end
    end
  end

  test "POST /rails_vitals/playgrounds forwards expression and association selection to sandbox and renders error state" do
    captured_call = nil

    sandbox_result = RailsVitals::Playground::Sandbox::Result.new(
      queries: [],
      query_count: 0,
      duration_ms: 0,
      error: "Execution error: invalid expression",
      model_name: nil,
      record_count: 0,
      score: nil,
      n1_patterns: []
    )

    run_stub = lambda do |expression, access_associations: []|
      captured_call = { expression: expression, access_associations: access_associations }
      sandbox_result
    end

    with_stub(RailsVitals::Playground::Sandbox, :run, run_stub) do
      with_stub(RailsVitals::Playground::Sandbox, :extract_model_name, "User") do
        with_stub(RailsVitals::Playground::Sandbox, :associations_for, [ "posts" ]) do
          post "/rails_vitals/playgrounds", params: {
            expression: "User.includes(:posts)",
            access_associations: [ "posts", "" ]
          }

          assert_response :success
          assert_includes response.body, "Execution error: invalid expression"
        end
      end
    end

    assert_equal(
      { expression: "User.includes(:posts)", access_associations: [ "posts" ] },
      captured_call
    )
  end
end
