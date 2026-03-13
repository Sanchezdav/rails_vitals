require "test_helper"

class RailsVitalsModelsControllerTest < ActionDispatch::IntegrationTest
  RecordDouble = Struct.new(:endpoint, :queries, :callbacks, keyword_init: true)
  StoreDouble = Struct.new(:all) do
    def find(_id)
      nil
    end
  end

  test "GET /rails_vitals/models returns per-model breakdown rows with query and callback aggregates" do
    records = [
      RecordDouble.new(
        endpoint: "UsersController#index",
        queries: [
          build_query(sql: 'SELECT * FROM "users" WHERE "users"."id" = 1', duration_ms: 7.0),
          build_query(sql: 'UPDATE "users" SET "name" = \'A\' WHERE "id" = 1', duration_ms: 4.0)
        ],
        callbacks: [ { model: "User", kind: :save, duration_ms: 1.2 } ]
      )
    ]

    with_stub(RailsVitals, :store, StoreDouble.new(records)) do
      get "/rails_vitals/models"
      assert_response :success
      assert_includes response.body, "Per-Model Breakdown"
      assert_includes response.body, "User"
      assert_includes response.body, "Triggered By"
    end
  end
end
