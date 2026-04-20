require "test_helper"
require "rails_vitals/mcp/tool_registry"

class RailsVitalsMCPToolRegistryTest < ActiveSupport::TestCase
  ToolRegistry = RailsVitals::MCP::ToolRegistry

  AlphaTool = Class.new do
    class << self
      def tool_name
        "alpha_tool"
      end

      def definition
        {
          name: tool_name,
          description: "Alpha tool"
        }
      end
    end
  end

  BetaTool = Class.new do
    class << self
      def tool_name
        "beta_tool"
      end

      def definition
        {
          name: tool_name,
          description: "Beta tool"
        }
      end
    end
  end

  ReplacementTool = Class.new do
    class << self
      def tool_name
        "alpha_tool"
      end

      def definition
        {
          name: tool_name,
          description: "Replacement alpha tool"
        }
      end
    end
  end

  def setup
    @original_registry = ToolRegistry.send(:registry).dup
    ToolRegistry.send(:registry).clear
  end

  def teardown
    ToolRegistry.send(:registry).clear
    ToolRegistry.send(:registry).merge!(@original_registry)
  end

  test ".register stores tool class under tool_name so .find returns that class" do
    ToolRegistry.register(AlphaTool)

    assert_equal AlphaTool, ToolRegistry.find("alpha_tool")
  end

  test ".register replaces previous class when another tool registers the same tool_name" do
    ToolRegistry.register(AlphaTool)
    ToolRegistry.register(ReplacementTool)

    assert_equal ReplacementTool, ToolRegistry.find("alpha_tool")
  end

  test ".all_definitions returns Array of registered tool definitions" do
    ToolRegistry.register(AlphaTool)
    ToolRegistry.register(BetaTool)

    definitions = ToolRegistry.all_definitions

    assert_equal 2, definitions.size
    assert_includes definitions, { name: "alpha_tool", description: "Alpha tool" }
    assert_includes definitions, { name: "beta_tool", description: "Beta tool" }
  end

  test ".all_definitions returns empty Array when no tools are registered" do
    assert_equal [], ToolRegistry.all_definitions
  end

  test ".find returns nil when a tool name is not registered" do
    assert_nil ToolRegistry.find("missing_tool")
  end

  test ".exists? returns true when a tool name is registered" do
    ToolRegistry.register(AlphaTool)

    assert ToolRegistry.exists?("alpha_tool")
  end

  test ".exists? returns false when a tool name is not registered" do
    refute ToolRegistry.exists?("missing_tool")
  end
end
