module RailsVitals
  module MCP
    module Tools
      class GetSlowQueries < Base
        TOOL_NAME = "railsvitals_get_slow_queries"

        DESCRIPTION = <<~DESC.strip
          Returns individual slow queries detected across recent requests, ordered by
          duration descending. Each result includes the SQL, execution time, and the
          endpoint that fired it. Use threshold_ms to override the default slow query
          threshold (configured via mcp_slow_query_threshold_ms, default 100ms).
          Use this after railsvitals_get_score to find which specific queries are
          dragging down database performance.
        DESC

        INPUT_SCHEMA = {
          type: "object",
          properties: {
            threshold_ms: {
              type: "integer",
              description: "Minimum query duration in ms to include. Defaults to config.mcp_slow_query_threshold_ms (100ms)."
            },
            limit: {
              type: "integer",
              description: "Maximum number of queries to return, ordered by duration desc. Defaults to 10."
            }
          }
        }.freeze

        DEFAULT_LIMIT = 10

        def call(params)
          records = RailsVitals.store.all
          return no_data_response if records.empty?

          threshold = (params[:threshold_ms] || params["threshold_ms"] || RailsVitals.config.mcp_slow_query_threshold_ms).to_i
          limit = (params[:limit] || params["limit"] || DEFAULT_LIMIT).to_i

          slow = collect_slow_queries(records, threshold)
          return no_slow_queries_response(threshold) if slow.empty?

          {
            total_slow_queries: slow.size,
            shown: [ limit, slow.size ].min,
            threshold_ms: threshold,
            queries: slow.first(limit).map { |q| serialize(q) }
          }
        end

        private

        def collect_slow_queries(records, threshold)
          queries = []

          records.each do |record|
            record.queries.each do |q|
              next if q[:duration_ms] < threshold

              queries << q.merge(endpoint: record.endpoint, request_id: record.id)
            end
          end

          queries.sort_by { |q| -q[:duration_ms] }
        end

        def serialize(query)
          {
            sql: query[:sql],
            duration_ms: query[:duration_ms].round(1),
            endpoint: query[:endpoint],
            request_id: query[:request_id]
          }
        end

        def no_data_response
          {
            total_slow_queries: 0,
            shown: 0,
            queries: [],
            message: "No requests recorded yet. Make some requests to the app first."
          }
        end

        def no_slow_queries_response(threshold)
          {
            total_slow_queries: 0,
            shown: 0,
            threshold_ms: threshold,
            queries: [],
            message: "No queries exceeded #{threshold}ms in recent requests."
          }
        end
      end

      ToolRegistry.register(GetSlowQueries)
    end
  end
end
