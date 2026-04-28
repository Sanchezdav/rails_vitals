module RailsVitals
  module MCP
    module Tools
      class GetSchemaContext < Base
        TOOL_NAME = "railsvitals_get_schema_context"

        DESCRIPTION = <<~DESC.strip
          Returns schema context for ActiveRecord models: columns with types, indexes,
          associations, and foreign keys missing an index. Use the models param to scope
          to specific models; omit it to get all models. Use this to understand your data
          model structure and spot missing indexes that could be causing slow queries or
          N+1 patterns.
        DESC

        INPUT_SCHEMA = {
          type: "object",
          properties: {
            models: {
              type: "array",
              items: { type: "string" },
              description: "Model names to include (e.g. ['Post', 'User']). Omit to return all models."
            }
          }
        }.freeze

        def call(params)
          requested = Array(params[:models] || params["models"]).map(&:to_s)

          all_models = Analyzers::AssociationMapper.discover_models
          models = requested.empty? ? all_models : filter_models(all_models, requested)

          return no_models_response(requested) if models.empty?

          {
            models_analyzed: models.size,
            models: models.map { |m| serialize_model(m) }
          }
        end

        private

        def filter_models(all_models, requested)
          all_models.select do |m|
            requested.any? { |r| m.name.downcase == r.downcase }
          end
        end

        def serialize_model(model)
          table = model.table_name
          columns = columns_for(table)
          indexes = indexes_for(table)
          assocs = serialize_associations(model, indexes)
          missing = assocs.select { |a| a[:macro] == "belongs_to" && !a[:indexed] }

          {
            name: model.name,
            table: table,
            columns: columns.map { |c| serialize_column(c) },
            indexes: indexes.map { |i| serialize_index(i) },
            associations: assocs,
            missing_indexes: missing.map { |a| { foreign_key: a[:foreign_key], association: a[:name] } }
          }
        end

        def serialize_column(col)
          { name: col.name, type: col.type.to_s, nullable: col.null }
        end

        def serialize_index(idx)
          { name: idx.name, columns: idx.columns, unique: idx.unique }
        end

        def serialize_associations(model, own_indexes)
          model.reflect_on_all_associations.filter_map do |assoc|
            target = assoc.klass rescue next

            fk = assoc.foreign_key.to_s
            if assoc.macro == :belongs_to
              indexed = own_indexes.any? { |i| i.columns.first == fk }
            else
              indexed = indexes_for(target.table_name).any? { |i| i.columns.first == fk }
            end

            {
              macro: assoc.macro.to_s,
              name: assoc.name.to_s,
              foreign_key: fk,
              to: target.name,
              indexed: indexed
            }
          end
        end

        def columns_for(table)
          ActiveRecord::Base.connection.columns(table)
        rescue StandardError
          []
        end

        def indexes_for(table)
          ActiveRecord::Base.connection.indexes(table)
        rescue StandardError
          []
        end

        def no_models_response(requested)
          msg = requested.empty? ? "No ActiveRecord models found." : "No models matched: #{requested.join(', ')}."
          { models_analyzed: 0, models: [], message: msg }
        end
      end

      ToolRegistry.register(GetSchemaContext)
    end
  end
end
