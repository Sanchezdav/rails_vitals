require "test_helper"

class RailsVitalsAssociationsControllerTest < ActionDispatch::IntegrationTest
  StoreDouble = Struct.new(:all) do
    def find(_id)
      nil
    end
  end

  test "GET /rails_vitals/associations returns association map response using [nodes, canvas_height] analyzer tuple" do
    node = RailsVitals::Analyzers::AssociationMapper::ModelNode.new(
      name: "User",
      table: "users",
      depth: 0,
      position: { x: 100, y: 100 },
      associations: [],
      query_count: 3,
      avg_query_time_ms: 5.2,
      has_n1: false,
      n1_patterns: []
    )

    with_stub(RailsVitals, :store, StoreDouble.new([])) do
      with_stub(RailsVitals::Analyzers::AssociationMapper, :build, [ [ node ], 280 ]) do
        get "/rails_vitals/associations"
        assert_response :success
        assert_includes response.body, "Association Map"
        assert_includes response.body, "User"
      end
    end
  end
end
