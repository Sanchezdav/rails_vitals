module RailsVitals
  class McpController < ActionController::API
    before_action :verify_environment
    before_action :verify_auth

    def call
      raw_body = request.body.read
      result   = handler.handle(raw_body)

      render json: result
    end

    private

    def verify_environment
      if Rails.env.production?
        render json: ResponseBuilder.error(
          nil,
          ResponseBuilder::AUTH_ERROR,
          "RailsVitals MCP is not available in production"
        ), status: :forbidden
      end
    end

    def verify_auth
      auth = MCP::Auth.new(RailsVitals.config.mcp_auth_token)

      unless auth.valid?(request)
        render json: MCP::ResponseBuilder.error(
          nil,
          MCP::ResponseBuilder::AUTH_ERROR,
          "Unauthorized",
          { detail: "Valid Bearer token required" }
        ), status: :unauthorized
      end
    end

    def handler
      @handler ||= MCP::RequestHandler.new
    end
  end
end
