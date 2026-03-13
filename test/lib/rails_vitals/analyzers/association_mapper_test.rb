require "test_helper"

class RailsVitalsAssociationMapperTest < ActiveSupport::TestCase
  StoreDouble = Struct.new(:all, keyword_init: true)
  RecordDouble = Struct.new(:queries, keyword_init: true)
  class ModelDouble
    attr_reader :name, :table_name

    def initialize(name:, table_name:, abstract:, exists:)
      @name = name
      @table_name = table_name
      @abstract = abstract
      @exists = exists
    end

    def abstract_class?
      @abstract
    end

    def table_exists?
      @exists
    end
  end

  test ".build returns [Array<ModelNode>, Integer canvas_height] tuple with node data contract" do
    model = Struct.new(:name, :table_name).new("User", "users")
    store = StoreDouble.new(all: [ RecordDouble.new(queries: [ build_query(sql: 'SELECT * FROM "users"', duration_ms: 5.0) ]) ])
    edge = RailsVitals::Analyzers::AssociationMapper::AssociationEdge.new(
      from_model: "User",
      to_model: "Post",
      macro: :has_many,
      foreign_key: "user_id",
      indexed: true,
      has_n1: false
    )

    with_stub(RailsVitals::Analyzers::AssociationMapper, :discover_models, [ model ]) do
      with_stub(RailsVitals::Analyzers::NPlusOneAggregator, :aggregate, [ { table: "users", pattern: "p" } ]) do
        with_stub(RailsVitals::Analyzers::AssociationMapper, :association_depth, 0) do
          with_stub(RailsVitals::Analyzers::AssociationMapper, :queries_for_model, store.all.first.queries) do
            with_stub(RailsVitals::Analyzers::AssociationMapper, :build_edges, [ edge ]) do
              nodes, canvas_height = RailsVitals::Analyzers::AssociationMapper.build(store)

              assert_kind_of Array, nodes
              assert_kind_of Integer, canvas_height
              assert_equal 1, nodes.size

              node = nodes.first
              assert_kind_of RailsVitals::Analyzers::AssociationMapper::ModelNode, node
              assert_equal "User", node.name
              assert_equal "users", node.table
              assert_equal 1, node.query_count
              assert node.has_n1
              assert_kind_of Array, node.associations
              assert_kind_of Array, node.n1_patterns
            end
          end
        end
      end
    end
  end

  test ".discover_models returns sorted non-abstract existing-table models excluding RailsVitals namespace" do
    models = [
      ModelDouble.new(name: "Zebra", table_name: "zebras", abstract: false, exists: true),
      ModelDouble.new(name: "RailsVitals::Internal", table_name: "internals", abstract: false, exists: true),
      ModelDouble.new(name: "Alpha", table_name: "alphas", abstract: false, exists: true),
      ModelDouble.new(name: "AbstractThing", table_name: "things", abstract: true, exists: true),
      ModelDouble.new(name: "NoTable", table_name: "no_tables", abstract: false, exists: false)
    ]

    with_stub(ActiveRecord::Base, :descendants, models) do
      result = RailsVitals::Analyzers::AssociationMapper.discover_models

      assert_equal [ "Alpha", "Zebra" ], result.map(&:name)
    end
  end

  test ".queries_for_model returns Array<Hash> matching FROM or UPDATE for model table name" do
    model = Struct.new(:table_name).new("users")
    records = [
      RecordDouble.new(queries: [
        build_query(sql: 'SELECT * FROM "users" WHERE "users"."id" = 1', duration_ms: 2.0),
        build_query(sql: 'SELECT * FROM "posts"', duration_ms: 2.0)
      ]),
      RecordDouble.new(queries: [
        build_query(sql: 'UPDATE "users" SET "name" = \'A\' WHERE "id" = 1', duration_ms: 3.0)
      ])
    ]

    result = RailsVitals::Analyzers::AssociationMapper.queries_for_model(model, records)

    assert_equal 2, result.size
    assert result.all? { |query| query[:sql].match?(/users/i) }
  end

  test ".assign_positions returns nodes with position Hash keys :x and :y and Integer canvas height" do
    node_one = RailsVitals::Analyzers::AssociationMapper::ModelNode.new(name: "A", table: "a", depth: 0)
    node_two = RailsVitals::Analyzers::AssociationMapper::ModelNode.new(name: "B", table: "b", depth: 1)

    nodes, canvas_height = RailsVitals::Analyzers::AssociationMapper.assign_positions([ node_one, node_two ])

    assert_equal 2, nodes.size
    assert_kind_of Integer, canvas_height
    assert_equal [ :x, :y ], nodes.first.position.keys
    assert_equal [ :x, :y ], nodes.last.position.keys
  end
end
