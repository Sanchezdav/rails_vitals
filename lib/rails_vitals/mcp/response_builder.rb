module RailsVitals
  module MCP
    module ResponseBuilder
      JSON_RPC_VERSION = "2.0"

      def self.success(id, result)
        {
          jsonrpc: JSON_RPC_VERSION,
          id: id,
          result: result
        }
      end

      def self.tool_success(id, data)
        success(id, {
          content: [
            {
              type: "text",
              text: data.to_json
            }
          ]
        })
      end

      def self.error(id, code, message, data = nil)
        err = { code: code, message: message }
        err[:data] = data if data.present?

        {
          jsonrpc: JSON_RPC_VERSION,
          id: id,
          error: err
        }
      end

      # JSON-RPC 2.0 standard error codes
      PARSE_ERROR      = -32_700
      INVALID_REQUEST  = -32_600
      METHOD_NOT_FOUND = -32_601
      INVALID_PARAMS   = -32_602

      # RailsVitals custom error codes
      AUTH_ERROR       = -32_000
      TOOL_EXEC_ERROR  = -32_001
    end
  end
end
