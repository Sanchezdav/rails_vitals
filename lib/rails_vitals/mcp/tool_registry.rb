module RailsVitals
  module MCP
    class ToolRegistry
      class << self
        def register(tool_class)
          registry[tool_class.tool_name] = tool_class
        end

        def all_definitions
          registry.values.map(&:definition)
        end

        def find(name)
          registry[name]
        end

        def exists?(name)
          registry.key?(name)
        end

        private

        def registry
          @registry ||= {}
        end
      end
    end
  end
end
