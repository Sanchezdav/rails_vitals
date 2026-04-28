require "test_helper"
require "rails_vitals/mcp/tools/base"
require "rails_vitals/mcp/tool_registry"
require "rails_vitals/mcp/tools/get_schema_context"

class RailsVitalsMCPToolsGetSchemaContextTest < ActiveSupport::TestCase
  GetSchemaContext = RailsVitals::MCP::Tools::GetSchemaContext
  Mapper = RailsVitals::Analyzers::AssociationMapper

  # --- doubles ---

  ColDouble = Struct.new(:name, :type, :null, keyword_init: true)
  IdxDouble = Struct.new(:name, :columns, :unique, keyword_init: true)
  AssocDouble = Struct.new(:name, :macro, :foreign_key, :klass, keyword_init: true)

  ModelDouble = Struct.new(:name, :table_name, :assoc_list, keyword_init: true) do
    def reflect_on_all_associations(_macro = nil) = assoc_list
  end

  ConnDouble = Struct.new(:col_map, :idx_map, keyword_init: true) do
    def columns(table) = col_map.fetch(table, [])
    def indexes(table) = idx_map.fetch(table, [])
  end

  def user_model
    user_class = ModelDouble.new(name: "User", table_name: "users", assoc_list: [
      AssocDouble.new(name: :posts, macro: :has_many, foreign_key: "user_id",
                      klass: post_model_class)
    ])
    user_class
  end

  def post_model_class
    @post_model_class ||= ModelDouble.new(name: "Post", table_name: "posts", assoc_list: [])
  end

  def post_model
    ModelDouble.new(name: "Post", table_name: "posts", assoc_list: [
      AssocDouble.new(name: :user, macro: :belongs_to, foreign_key: "user_id",
                      klass: user_model_class)
    ])
  end

  def user_model_class
    @user_model_class ||= ModelDouble.new(name: "User", table_name: "users", assoc_list: [])
  end

  def stub_connection(col_map: {}, idx_map: {})
    conn = ConnDouble.new(col_map: col_map, idx_map: idx_map)
    with_stub(ActiveRecord::Base, :connection, conn) { yield }
  end

  def call_tool(params: {}, models: [])
    with_stub(Mapper, :discover_models, models) do
      stub_connection(
        col_map: {
          "posts" => [ ColDouble.new(name: "id",      type: :integer, null: false),
                       ColDouble.new(name: "title",   type: :string,  null: false),
                       ColDouble.new(name: "user_id", type: :integer, null: false) ],
          "users" => [ ColDouble.new(name: "id",   type: :integer, null: false),
                       ColDouble.new(name: "email", type: :string,  null: false) ]
        },
        idx_map: {
          "posts" => [ IdxDouble.new(name: "index_posts_on_user_id", columns: [ "user_id" ], unique: false) ],
          "users" => []
        }
      ) do
        GetSchemaContext.new.call(params)
      end
    end
  end

  # --- no models ---

  test "#call returns no-models response when discover returns empty" do
    with_stub(Mapper, :discover_models, []) do
      result = GetSchemaContext.new.call({})

      assert_equal 0, result[:models_analyzed]
      assert_equal [], result[:models]
      assert_includes result[:message], "No ActiveRecord models found"
    end
  end

  test "#call returns no-models response when filter matches nothing" do
    result = call_tool(params: { models: [ "NonExistent" ] }, models: [ post_model ])

    assert_equal 0, result[:models_analyzed]
    assert_includes result[:message], "NonExistent"
  end

  # --- models filter ---

  test "#call returns all models when models param is empty" do
    result = call_tool(models: [ post_model, user_model ])

    assert_equal 2, result[:models_analyzed]
  end

  test "#call filters models by name case-insensitively" do
    result = call_tool(params: { models: [ "post" ] }, models: [ post_model, user_model ])

    assert_equal 1, result[:models_analyzed]
    assert_equal "Post", result[:models].first[:name]
  end

  test "#call accepts string models key from JSON params" do
    result = call_tool(params: { "models" => [ "Post" ] }, models: [ post_model, user_model ])

    assert_equal 1, result[:models_analyzed]
  end

  # --- column serialization ---

  test "#call serializes columns with name type and nullable" do
    result = call_tool(models: [ post_model ])
    cols = result[:models].first[:columns]

    id_col = cols.find { |c| c[:name] == "id" }
    assert_equal "integer", id_col[:type]
    assert_equal false, id_col[:nullable]

    user_id_col = cols.find { |c| c[:name] == "user_id" }
    assert_equal "integer", user_id_col[:type]
  end

  # --- index serialization ---

  test "#call serializes indexes with name columns and unique flag" do
    result = call_tool(models: [ post_model ])
    idx = result[:models].first[:indexes].first

    assert_equal "index_posts_on_user_id", idx[:name]
    assert_equal [ "user_id" ], idx[:columns]
    assert_equal false, idx[:unique]
  end

  # --- association serialization ---

  test "#call serializes associations with macro name foreign_key to and indexed" do
    result = call_tool(models: [ post_model ])
    assoc = result[:models].first[:associations].first

    assert_equal "belongs_to", assoc[:macro]
    assert_equal "user", assoc[:name]
    assert_equal "user_id", assoc[:foreign_key]
    assert_equal "User", assoc[:to]
    assert_equal true, assoc[:indexed]
  end

  # --- missing indexes ---

  test "#call detects missing_indexes for belongs_to FK without an index" do
    unindexed_post = ModelDouble.new(name: "Post", table_name: "posts", assoc_list: [
      AssocDouble.new(name: :user, macro: :belongs_to, foreign_key: "user_id",
                      klass: user_model_class)
    ])

    with_stub(Mapper, :discover_models, [ unindexed_post ]) do
      stub_connection(
        col_map: { "posts" => [ ColDouble.new(name: "user_id", type: :integer, null: false) ] },
        idx_map: { "posts" => [] }  # no index on user_id
      ) do
        result = GetSchemaContext.new.call({})
        missing = result[:models].first[:missing_indexes]

        assert_equal 1, missing.size
        assert_equal "user_id", missing.first[:foreign_key]
        assert_equal "user", missing.first[:association]
      end
    end
  end

  test "#call returns empty missing_indexes when all belongs_to FKs are indexed" do
    result = call_tool(models: [ post_model ])  # posts has index on user_id

    assert_equal [], result[:models].first[:missing_indexes]
  end

  test "#call does not flag has_many associations in missing_indexes" do
    result = call_tool(models: [ user_model ])
    missing = result[:models].first[:missing_indexes]

    # has_many :posts is on users model — user_id FK lives on posts table, not users
    assert_equal [], missing
  end

  # --- registration ---

  test "GetSchemaContext is registered in ToolRegistry under its TOOL_NAME" do
    assert_equal GetSchemaContext, RailsVitals::MCP::ToolRegistry.find(GetSchemaContext::TOOL_NAME)
  end

  test ".definition includes name description and inputSchema with models property" do
    defn = GetSchemaContext.definition

    assert_equal GetSchemaContext::TOOL_NAME, defn[:name]
    assert defn[:description].length > 10
    assert defn[:inputSchema][:properties].key?(:models)
  end
end
