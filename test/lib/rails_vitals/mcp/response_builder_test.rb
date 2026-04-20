require "test_helper"
require "rails_vitals/mcp/response_builder"

class RailsVitalsMCPResponseBuilderTest < ActiveSupport::TestCase
  ResponseBuilder = RailsVitals::MCP::ResponseBuilder

  test ".success returns Hash with jsonrpc id and result keys" do
    result = { protocolVersion: "2025-11-25", capabilities: { tools: {} } }
    response = ResponseBuilder.success(7, result)

    assert_equal "2.0", response[:jsonrpc]
    assert_equal 7, response[:id]
    assert_equal result, response[:result]
  end

  test ".tool_success returns Hash with result content Array containing text json payload" do
    data = { ok: true, score: 92, warnings: [ "n+1 detected" ] }
    response = ResponseBuilder.tool_success(8, data)

    assert_equal "2.0", response[:jsonrpc]
    assert_equal 8, response[:id]
    assert_equal 1, response[:result][:content].size
    assert_equal "text", response[:result][:content].first[:type]
    assert_equal data, JSON.parse(response[:result][:content].first[:text], symbolize_names: true)
  end

  test ".error returns Hash with jsonrpc id and error keys when data is nil" do
    response = ResponseBuilder.error(9, ResponseBuilder::INVALID_REQUEST, "Missing method")

    assert_equal "2.0", response[:jsonrpc]
    assert_equal 9, response[:id]
    assert_equal ResponseBuilder::INVALID_REQUEST, response[:error][:code]
    assert_equal "Missing method", response[:error][:message]
    refute response[:error].key?(:data)
  end

  test ".error returns Hash with error data when data is present" do
    data = { tool: "dummy_tool", detail: "boom" }
    response = ResponseBuilder.error(10, ResponseBuilder::TOOL_EXEC_ERROR, "Tool execution failed", data)

    assert_equal "2.0", response[:jsonrpc]
    assert_equal 10, response[:id]
    assert_equal ResponseBuilder::TOOL_EXEC_ERROR, response[:error][:code]
    assert_equal "Tool execution failed", response[:error][:message]
    assert_equal data, response[:error][:data]
  end

  test "error code constants expose expected JSON-RPC and custom integer values" do
    assert_equal(-32_700, ResponseBuilder::PARSE_ERROR)
    assert_equal(-32_600, ResponseBuilder::INVALID_REQUEST)
    assert_equal(-32_601, ResponseBuilder::METHOD_NOT_FOUND)
    assert_equal(-32_602, ResponseBuilder::INVALID_PARAMS)
    assert_equal(-32_000, ResponseBuilder::AUTH_ERROR)
    assert_equal(-32_001, ResponseBuilder::TOOL_EXEC_ERROR)
  end
end
