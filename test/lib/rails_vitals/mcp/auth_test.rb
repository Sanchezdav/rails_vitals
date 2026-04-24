require "test_helper"
require "rails_vitals/mcp/auth"

class RailsVitalsMCPAuthTest < ActiveSupport::TestCase
  RequestDouble = Struct.new(:authorization) do
    def get_header(name)
      return authorization if name == "HTTP_AUTHORIZATION"

      raise ArgumentError, "unexpected header: #{name}"
    end
  end

  test "#valid? returns false when expected token is blank without reading request headers" do
    auth = RailsVitals::MCP::Auth.new(nil)
    request = Object.new
    request.define_singleton_method(:get_header) do |_name|
      raise "get_header should not be called when token is blank"
    end

    refute auth.valid?(request)
  end

  test "#valid? returns false when authorization header is missing" do
    auth = RailsVitals::MCP::Auth.new("secret-token")

    refute auth.valid?(RequestDouble.new(nil))
  end

  test "#valid? returns false when authorization header is not a Bearer token" do
    auth = RailsVitals::MCP::Auth.new("secret-token")

    refute auth.valid?(RequestDouble.new("Basic abc123"))
    refute auth.valid?(RequestDouble.new("Token secret-token"))
  end

  test "#valid? returns true when Bearer token exactly matches expected token" do
    auth = RailsVitals::MCP::Auth.new("secret-token")

    assert auth.valid?(RequestDouble.new("Bearer secret-token"))
  end

  test "#valid? returns false when Bearer token does not match expected token" do
    auth = RailsVitals::MCP::Auth.new("secret-token")

    refute auth.valid?(RequestDouble.new("Bearer wrong-token"))
  end

  test "#valid? returns false when Bearer token has different case than expected token" do
    auth = RailsVitals::MCP::Auth.new("secret-token")

    refute auth.valid?(RequestDouble.new("Bearer SECRET-TOKEN"))
  end

  test "#valid? returns false when header uses lowercase bearer scheme" do
    auth = RailsVitals::MCP::Auth.new("secret-token")

    refute auth.valid?(RequestDouble.new("bearer secret-token"))
  end
end
