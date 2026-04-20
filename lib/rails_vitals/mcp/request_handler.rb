module RailsVitals
  module MCP
    class RequestHandler
      include ResponseBuilder

      SERVER_INFO = {
        name: "railsvitals",
        version: RailsVitals::VERSION
      }.freeze

      PROTOCOL_VERSION = "2025-11-25"
      JSON_RPC_VERSION = "2.0"

      INSTRUCTIONS = <<~TEXT.strip
        RailsVitals exposes Rails app performance diagnostics.
        Recommended flow: call railsvitals_get_schema_context first to understand
        the data model, then railsvitals_get_score for a high-level diagnosis,
        then drill down with the specific query tools.
      TEXT

      def handle(raw_body)
        payload = parse_json(raw_body)
        return payload if payload.is_a?(Hash) && payload[:error]

        id = payload[:id]
        method = payload[:method]

        unless method.present?
          return ResponseBuilder.error(id, ResponseBuilder::INVALID_REQUEST, "Missing method")
        end

        case method
        when "initialize" then handle_initialize(id, payload[:params] || {})
        when "tools/list" then handle_tools_list(id)
        when "tools/call" then handle_tools_call(id, payload[:params] || {})
        else
          ResponseBuilder.error(id, ResponseBuilder::METHOD_NOT_FOUND, "Method not found: #{method}")
        end
      end

      private

      def parse_json(raw_body)
        payload = JSON.parse(raw_body, symbolize_names: true)

        unless payload[:jsonrpc] == JSON_RPC_VERSION
          return ResponseBuilder.error(nil, ResponseBuilder::INVALID_REQUEST, "jsonrpc must be '#{JSON_RPC_VERSION}'")
        end

        payload
      rescue JSON::ParserError => e
        ResponseBuilder.error(nil, ResponseBuilder::PARSE_ERROR, "Parse error: #{e.message}")
      end

      def handle_initialize(id, _params)
        ResponseBuilder.success(id, {
          protocolVersion: PROTOCOL_VERSION,
          serverInfo: SERVER_INFO,
          capabilities: { tools: {} },
          instructions: INSTRUCTIONS
        })
      end

      def handle_tools_list(id)
        ResponseBuilder.success(id, {
          tools: ToolRegistry.all_definitions
        })
      end

      def handle_tools_call(id, params)
        name = params[:name]
        arguments = params[:arguments] || {}

        unless name.present?
          return ResponseBuilder.error(id, ResponseBuilder::INVALID_PARAMS, "Missing tool name")
        end

        tool_class = ToolRegistry.find(name)

        unless tool_class
          return ResponseBuilder.error(
            id,
            ResponseBuilder::METHOD_NOT_FOUND,
            "Tool not found",
            { tool: name }
          )
        end

        result = tool_class.new.call(arguments)
        ResponseBuilder.tool_success(id, result)
      rescue => e
        ResponseBuilder.error(
          id,
          ResponseBuilder::TOOL_EXEC_ERROR,
          "Tool execution failed",
          { tool: name, detail: e.message }
        )
      end
    end
  end
end
