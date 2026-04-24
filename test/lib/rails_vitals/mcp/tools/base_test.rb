require "test_helper"
require "rails_vitals/mcp/tools/base"

class RailsVitalsMCPToolsBaseTest < ActiveSupport::TestCase
  BaseTool = RailsVitals::MCP::Tools::Base

  ExampleTool = Class.new(BaseTool)
  ExampleTool.const_set(:TOOL_NAME, "railsvitals_example")
  ExampleTool.const_set(:DESCRIPTION, "Example MCP tool")
  ExampleTool.const_set(:INPUT_SCHEMA, {
    type: "object",
    properties: {
      limit: { type: "integer" }
    }
  }.freeze)

  test ".tool_name returns TOOL_NAME constant value from subclass" do
    assert_equal "railsvitals_example", ExampleTool.tool_name
  end

  test ".definition returns Hash with keys :name :description and :inputSchema from subclass constants" do
    definition = ExampleTool.definition

    assert_equal "railsvitals_example", definition[:name]
    assert_equal "Example MCP tool", definition[:description]
    assert_equal ExampleTool::INPUT_SCHEMA, definition[:inputSchema]
  end

  test "#call raises NotImplementedError with class-specific message when subclass does not implement it" do
    error = assert_raises(NotImplementedError) { ExampleTool.new.call({}) }
    assert_equal "#{ExampleTool}#call is not implemented", error.message
  end
end
