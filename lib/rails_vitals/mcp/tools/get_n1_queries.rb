module RailsVitals
  module MCP
    module Tools
      class GetN1Queries < Base
        TOOL_NAME = "railsvitals_get_n1_queries"

        DESCRIPTION = <<~DESC.strip
          Returns all N+1 query patterns detected across recent requests, grouped and
          ranked by number of occurrences. Each pattern includes the normalized SQL
          fingerprint, affected endpoints with hit counts, and a deterministic fix
          suggestion (the correct includes() call) derived from ActiveRecord reflection.
          Use this after railsvitals_get_score to identify which N+1 patterns to fix.
        DESC

        INPUT_SCHEMA = {
          type: "object",
          properties: {
            limit: {
              type: "integer",
              description: "Maximum number of patterns to return, ordered by occurrences desc. Defaults to 10."
            }
          }
        }.freeze

        DEFAULT_LIMIT = 10

        def call(params)
          records = RailsVitals.store.all
          return no_data_response if records.empty?

          limit = (params[:limit] || params["limit"] || DEFAULT_LIMIT).to_i
          patterns = Analyzers::NPlusOneAggregator.aggregate(records)

          return no_n1_response if patterns.empty?

          {
            total_patterns: patterns.size,
            shown: [ limit, patterns.size ].min,
            patterns: patterns.first(limit).map { |p| serialize(p) }
          }
        end

        private

        def no_data_response
          {
            total_patterns: 0,
            shown: 0,
            patterns: [],
            message: "No requests recorded yet. Make some requests to the app first."
          }
        end

        def no_n1_response
          {
            total_patterns: 0,
            shown: 0,
            patterns: [],
            message: "No N+1 patterns detected in recent requests."
          }
        end

        def serialize(pattern)
          {
            pattern: pattern[:pattern],
            occurrences: pattern[:occurrences],
            table: pattern[:table],
            foreign_key: pattern[:foreign_key],
            affected_endpoints: serialize_endpoints(pattern[:endpoints]),
            fix: serialize_fix(pattern[:fix_suggestion])
          }
        end

        def serialize_endpoints(endpoints)
          endpoints
            .sort_by { |_, count| -count }
            .map { |endpoint, count| { endpoint: endpoint, request_count: count } }
        end

        def serialize_fix(suggestion)
          {
            code: suggestion[:code],
            description: suggestion[:description],
            owner: suggestion[:owner],
            association: suggestion[:association]
          }
        end
      end

      ToolRegistry.register(GetN1Queries)
    end
  end
end
