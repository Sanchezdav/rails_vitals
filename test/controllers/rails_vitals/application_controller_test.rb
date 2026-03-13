require "test_helper"
require "base64"

class RailsVitalsApplicationControllerTest < ActionDispatch::IntegrationTest
  StoreDouble = Struct.new(:all) do
    def find(_id)
      nil
    end
  end

  test "before_action authenticate! returns success response when auth is :none" do
    with_rails_vitals_config(auth: :none) do
      with_stub(RailsVitals, :store, StoreDouble.new([])) do
        get "/rails_vitals"
        assert_response :success
      end
    end
  end

  test "before_action authenticate! returns 401 response when auth is :basic and credentials are missing" do
    with_rails_vitals_config(auth: :basic, basic_auth_username: "dev", basic_auth_password: "secret") do
      with_stub(RailsVitals, :store, StoreDouble.new([])) do
        get "/rails_vitals"
        assert_response :unauthorized
      end
    end
  end

  test "before_action authenticate! returns success response when auth is :basic and credentials match" do
    token = Base64.strict_encode64("dev:secret")

    with_rails_vitals_config(auth: :basic, basic_auth_username: "dev", basic_auth_password: "secret") do
      with_stub(RailsVitals, :store, StoreDouble.new([])) do
        get "/rails_vitals", headers: { "HTTP_AUTHORIZATION" => "Basic #{token}" }
        assert_response :success
      end
    end
  end

  test "before_action authenticate! returns 401 response when auth proc returns false" do
    with_rails_vitals_config(auth: ->(_controller) { false }) do
      with_stub(RailsVitals, :store, StoreDouble.new([])) do
        get "/rails_vitals"
        assert_response :unauthorized
        assert_includes response.body, "Unauthorized"
      end
    end
  end
end
