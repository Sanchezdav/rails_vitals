module RailsVitals
  module MCP
    module Tools
      class GetRequestLog < Base
        TOOL_NAME = "railsvitals_get_request_log"
        DEFAULT_LIMIT = 20

        DESCRIPTION = <<~DESC.strip
          Returns recent requests recorded by RailsVitals, ordered most recent first.
          Each entry includes endpoint, health score, query count, total DB time, N+1
          pattern count, and request duration. Use the controller param to scope results
          to a specific controller. Use this to spot whether problems are consistent or
          intermittent and to identify which requests to investigate further.
        DESC

        INPUT_SCHEMA = {
          type: "object",
          properties: {
            controller: {
              type: "string",
              description: "Filter by controller name (case-insensitive, partial match). 'Feed' matches FeedController."
            },
            limit: {
              type: "integer",
              description: "Maximum number of requests to return, most recent first. Defaults to 20."
            }
          }
        }.freeze

        def call(params)
          records = RailsVitals.store.all
          return no_data_response if records.empty?

          controller_filter = params[:controller] || params["controller"]
          limit = (params[:limit] || params["limit"] || DEFAULT_LIMIT).to_i

          filtered = filter_records(records, controller_filter)
          return no_match_response(controller_filter) if filtered.empty?

          shown = filtered.last(limit).reverse

          {
            total_requests: filtered.size,
            shown: shown.size,
            controller_filter: controller_filter,
            requests: shown.map { |r| serialize(r) }
          }
        end

        private

        def filter_records(records, controller_filter)
          return records unless controller_filter

          records.select { |r| r.controller.downcase.include?(controller_filter.downcase) }
        end

        def serialize(record)
          {
            request_id: record.id,
            endpoint: record.endpoint,
            score: record.score,
            grade: record.label,
            query_count: record.total_query_count,
            db_time_ms: record.total_db_time_ms.round(1),
            n1_patterns: record.n_plus_one_patterns.size,
            duration_ms: record.duration_ms&.round(1),
            recorded_at: record.recorded_at.strftime("%H:%M:%S")
          }
        end

        def no_data_response
          {
            total_requests: 0,
            shown: 0,
            controller_filter: nil,
            requests: [],
            message: "No requests recorded yet. Make some requests to the app first."
          }
        end

        def no_match_response(controller_filter)
          {
            total_requests: 0,
            shown: 0,
            controller_filter: controller_filter,
            requests: [],
            message: "No requests matched controller '#{controller_filter}'."
          }
        end
      end

      ToolRegistry.register(GetRequestLog)
    end
  end
end
