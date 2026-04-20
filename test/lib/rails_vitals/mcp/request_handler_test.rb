require "test_helper"
require "rails_vitals/mcp/response_builder"
require "rails_vitals/mcp/tool_registry"
require "rails_vitals/mcp/request_handler"

class RailsVitalsMCPRequestHandlerTest < ActiveSupport::TestCase
  Handler = RailsVitals::MCP::RequestHandler
  ResponseBuilder = RailsVitals::MCP::ResponseBuilder
  ToolRegistry = RailsVitals::MCP::ToolRegistry

  DummyTool = Class.new do
    class << self
      def tool_name
        "dummy_tool"
      end

      def definition
        {
          name: tool_name,
          description: "Dummy tool for request handler tests"
        }
      end
    end

    def call(arguments)
      {
        echoed: arguments,
        ok: true
      }
    end
  end

  ExplodingTool = Class.new do
    class << self
      def tool_name
        "exploding_tool"
      end

      def definition
        {
          name: tool_name,
          description: "Explodes when called"
        }
      end
    end

    def call(_arguments)
      raise "boom"
    end
  end

  def setup
    @handler = Handler.new
  end

  test "#handle returns parse error response when raw body is invalid JSON" do
    response = @handler.handle("{invalid json")

    assert_equal "2.0", response[:jsonrpc]
    assert_nil response[:id]
    assert_equal ResponseBuilder::PARSE_ERROR, response[:error][:code]
    assert_includes response[:error][:message], "Parse error"
  end

  test "#handle returns invalid request response when jsonrpc version is not 2.0" do
    response = @handler.handle({ jsonrpc: "1.0", id: 7, method: "initialize" }.to_json)

    assert_equal "2.0", response[:jsonrpc]
    assert_nil response[:id]
    assert_equal ResponseBuilder::INVALID_REQUEST, response[:error][:code]
    assert_equal "jsonrpc must be '2.0'", response[:error][:message]
  end

  test "#handle returns invalid request response when method is missing" do
    response = @handler.handle({ jsonrpc: "2.0", id: 9 }.to_json)

    assert_equal 9, response[:id]
    assert_equal ResponseBuilder::INVALID_REQUEST, response[:error][:code]
    assert_equal "Missing method", response[:error][:message]
  end

  test "#handle returns initialize success payload with protocol version server info capabilities and instructions" do
    response = @handler.handle({ jsonrpc: "2.0", id: 1, method: "initialize", params: {} }.to_json)

    assert_equal "2.0", response[:jsonrpc]
    assert_equal 1, response[:id]
    assert_equal Handler::PROTOCOL_VERSION, response[:result][:protocolVersion]
    assert_equal Handler::SERVER_INFO, response[:result][:serverInfo]
    assert_equal({ tools: {} }, response[:result][:capabilities])
    assert_includes response[:result][:instructions], "railsvitals_get_schema_context"
  end

  test "#handle returns tools/list success payload with tool definitions from ToolRegistry" do
    all_defs_stub = [ { name: "dummy_tool", description: "Dummy tool for request handler tests" } ]

    with_stub(ToolRegistry, :all_definitions, all_defs_stub) do
      response = @handler.handle({ jsonrpc: "2.0", id: 2, method: "tools/list" }.to_json)

      assert_equal 2, response[:id]
      assert_equal all_defs_stub, response[:result][:tools]
    end
  end

  test "#handle returns invalid params response when tools/call is missing tool name" do
    response = @handler.handle({ jsonrpc: "2.0", id: 3, method: "tools/call", params: {} }.to_json)

    assert_equal 3, response[:id]
    assert_equal ResponseBuilder::INVALID_PARAMS, response[:error][:code]
    assert_equal "Missing tool name", response[:error][:message]
  end

  test "#handle returns method not found response with tool data when tools/call references unknown tool" do
    with_stub(ToolRegistry, :find, nil) do
      response = @handler.handle(
        { jsonrpc: "2.0", id: 4, method: "tools/call", params: { name: "unknown_tool" } }.to_json
      )

      assert_equal 4, response[:id]
      assert_equal ResponseBuilder::METHOD_NOT_FOUND, response[:error][:code]
      assert_equal "Tool not found", response[:error][:message]
      assert_equal({ tool: "unknown_tool" }, response[:error][:data])
    end
  end

  test "#handle returns tool success response with JSON text content when tools/call succeeds" do
    with_stub(ToolRegistry, :find, DummyTool) do
      response = @handler.handle(
        {
          jsonrpc: "2.0",
          id: 5,
          method: "tools/call",
          params: {
            name: "dummy_tool",
            arguments: { query: "slow requests", limit: 5 }
          }
        }.to_json
      )

      assert_equal 5, response[:id]
      assert_equal "text", response[:result][:content].first[:type]

      parsed_tool_payload = JSON.parse(response[:result][:content].first[:text], symbolize_names: true)
      assert_equal true, parsed_tool_payload[:ok]
      assert_equal({ query: "slow requests", limit: 5 }, parsed_tool_payload[:echoed])
    end
  end

  test "#handle returns tool execution error response with tool name and exception detail when tool raises" do
    with_stub(ToolRegistry, :find, ExplodingTool) do
      response = @handler.handle(
        {
          jsonrpc: "2.0",
          id: 6,
          method: "tools/call",
          params: {
            name: "exploding_tool",
            arguments: { anything: true }
          }
        }.to_json
      )

      assert_equal 6, response[:id]
      assert_equal ResponseBuilder::TOOL_EXEC_ERROR, response[:error][:code]
      assert_equal "Tool execution failed", response[:error][:message]
      assert_equal "exploding_tool", response[:error][:data][:tool]
      assert_equal "boom", response[:error][:data][:detail]
    end
  end

  test "#handle returns method not found response when request method is unsupported" do
    response = @handler.handle({ jsonrpc: "2.0", id: 8, method: "unknown/method" }.to_json)

    assert_equal 8, response[:id]
    assert_equal ResponseBuilder::METHOD_NOT_FOUND, response[:error][:code]
    assert_equal "Method not found: unknown/method", response[:error][:message]
  end
end
