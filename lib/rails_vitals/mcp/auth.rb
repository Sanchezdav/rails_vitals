module RailsVitals
  module MCP
    class Auth
      BEARER_PATTERN = /\ABearer (.+)\z/

      def initialize(token)
        @expected_token = token
      end

      def valid?(request)
        return false if @expected_token.blank?

        auth_header = request.get_header("HTTP_AUTHORIZATION") || ""
        match = BEARER_PATTERN.match(auth_header)
        return false unless match

        ActiveSupport::SecurityUtils.secure_compare(match[1], @expected_token)
      end
    end
  end
end
