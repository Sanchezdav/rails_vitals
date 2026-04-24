module RailsVitals
  module MCP
    module Tools
      class Base
        # Subclasses must define:
        #   TOOL_NAME = "railsvitals_example"
        #   DESCRIPTION = "What this tool does for the AI model"
        #   INPUT_SCHEMA = { type: "object", properties: {} }
        #
        # And implement:
        #   def call(params) → Hash

        def self.tool_name
          self::TOOL_NAME
        end

        def self.definition
          {
            name: self::TOOL_NAME,
            description: self::DESCRIPTION,
            inputSchema: self::INPUT_SCHEMA
          }
        end

        def call(params)
          raise NotImplementedError, "#{self.class}#call is not implemented"
        end
      end
    end
  end
end
