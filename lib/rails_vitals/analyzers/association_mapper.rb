module RailsVitals
  module Analyzers
    class AssociationMapper
      ModelNode = Struct.new(
        :name, :table, :depth, :position,
        :associations, :query_count, :avg_query_time_ms,
        :has_n1, :n1_patterns,
        keyword_init: true
      )

      AssociationEdge = Struct.new(
        :from_model, :to_model, :macro,
        :foreign_key, :indexed, :has_n1,
        keyword_init: true
      )

      def self.build(store)
        records = store.all
        models = discover_models
        n1_data = NPlusOneAggregator.aggregate(records)
        n1_tables = n1_data.map { |p| p[:table] }.compact.uniq

        nodes = models.map do |model|
          queries = queries_for_model(model, records)
          avg_time = queries.empty? ? 0 : (queries.sum { |q| q[:duration_ms] } / queries.size).round(2)

          ModelNode.new(
            name: model.name,
            table: model.table_name,
            depth: association_depth(model, models),
            position: nil,
            associations: build_edges(model, n1_tables),
            query_count: queries.size,
            avg_query_time_ms: avg_time,
            has_n1: n1_tables.include?(model.table_name),
            n1_patterns: n1_data.select { |p| p[:table] == model.table_name }
          )
        end

        nodes, canvas_h = assign_positions(nodes)
        [ nodes, canvas_h ]
      end

      def self.discover_models
        ActiveRecord::Base.descendants
          .reject(&:abstract_class?)
          .reject { |m| m.name&.start_with?("RailsVitals") }
          .select { |m| m.table_exists? rescue false }
          .sort_by(&:name)
      end

      # Depth = how many belongs_to hops from root
      def self.association_depth(model, all_models)
        belongs_to_targets = model.reflect_on_all_associations(:belongs_to)
          .map { |r| r.klass rescue nil }
          .compact

        return 0 if belongs_to_targets.empty?

        belongs_to_targets.map { |target|
          target == model ? 0 : association_depth(target, all_models) + 1
        }.min
      rescue
        0
      end

      def self.build_edges(model, n1_tables)
        model.reflect_on_all_associations.map do |assoc|
          target = assoc.klass rescue next
          fk = assoc.foreign_key.to_s
          table = assoc.macro == :belongs_to ? model.table_name : target.table_name

          indexed = begin
            ActiveRecord::Base.connection
              .indexes(table)
              .any? { |i| i.columns.first == fk }
          rescue
            false
          end

          AssociationEdge.new(
            from_model: model.name,
            to_model: target.name,
            macro: assoc.macro,
            foreign_key: fk,
            indexed: indexed,
            has_n1: n1_tables.include?(target.table_name)
          )
        end.compact
      end

      def self.queries_for_model(model, records)
        records.flat_map { |r| r.queries }
          .select { |q|
            q[:sql].match?(/FROM\s+"?#{model.table_name}"?/i) ||
            q[:sql].match?(/UPDATE\s+"?#{model.table_name}"?/i)
          }
      end

      # Assign x/y positions by depth layer
      def self.assign_positions(nodes)
        by_depth = nodes.group_by(&:depth)
        canvas_w = 900
        canvas_h = 120 + (by_depth.keys.max || 0) * 160

        by_depth.each do |depth, layer_nodes|
          count  = layer_nodes.size
          x_step = canvas_w / (count + 1)
          layer_nodes.each_with_index do |node, i|
            node.position = {
              x: x_step * (i + 1),
              y: 60 + depth * 160
            }
          end
        end

        [ nodes, canvas_h ]
      end
    end
  end
end
