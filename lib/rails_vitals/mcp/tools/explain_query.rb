module RailsVitals
  module MCP
    module Tools
      class ExplainQuery < Base
        TOOL_NAME = "railsvitals_explain_query"

        DESCRIPTION = <<~DESC.strip
          Runs EXPLAIN ANALYZE on a SELECT query and returns the execution plan summary:
          total cost, actual execution time, rows examined, detected warnings (Seq Scan,
          Sort without index, large Nested Loop), and deterministic fix suggestions with
          migration hints. Only SELECT statements are accepted — any SQL containing DML
          keywords (INSERT, UPDATE, DELETE, DROP, TRUNCATE, ALTER) is rejected, including
          CTEs. Use this to investigate a specific slow query from railsvitals_get_slow_queries.

          When presenting results, always lead with the interpretation field as a plain-English
          verdict. Then highlight each warning by name and explain what it means for this specific
          query (table name, rows scanned). For each suggestion, show the body explanation first,
          then the migration snippet in a code block, then the generator command if present.
          Avoid listing raw numbers without context — translate total_cost and rows_examined into
          plain language (e.g. "scanned 50,000 rows to return 3" instead of "rows_examined: 50000").
        DESC

        INPUT_SCHEMA = {
          type: "object",
          required: [ "sql" ],
          properties: {
            sql: {
              type: "string",
              description: "The SELECT query to explain. Must not contain INSERT, UPDATE, DELETE, DROP, TRUNCATE, or ALTER — including inside CTEs."
            }
          }
        }.freeze

        DML_PATTERN = /\b(INSERT|UPDATE|DELETE|DROP|TRUNCATE|ALTER|CREATE)\b/i.freeze

        def call(params)
          sql = params[:sql] || params["sql"]

          return missing_sql_response if sql.nil? || sql.strip.empty?
          return rejected_sql_response(sql) if dml_present?(sql)

          cleaned_sql = sql.strip

          cost_estimate = Analyzers::ExplainAnalyzer.dry_run(cleaned_sql)
          if cost_estimate.error
            return error_response("Cost estimate failed: #{cost_estimate.error}")
          end

          result = Analyzers::ExplainAnalyzer.analyze(cleaned_sql)

          return error_response(result.error) if result.error

          {
            sql: result.sql,
            total_cost: result.total_cost,
            actual_time_ms: result.actual_time_ms,
            rows_examined: result.rows_examined,
            cost_estimate: {
              total_cost: cost_estimate.total_cost,
              note: "Cost estimate from dry-run EXPLAIN (ANALYZE was not executed for this estimate)"
            },
            function_calls: result.function_calls,
            warnings: serialize_warnings(result.warnings),
            suggestions: serialize_suggestions(result.suggestions),
            interpretation: result.interpretation
          }
        end

        private

        def dml_present?(sql)
          sql.match?(DML_PATTERN)
        end

        def serialize_warnings(warnings)
          warnings.map do |w|
            entry = { type: w[:type].to_s, severity: w[:severity].to_s }
            entry[:table] = w[:table] if w[:table]
            entry[:rows_scanned] = w[:rows] if w[:rows]
            entry
          end
        end

        def serialize_suggestions(suggestions)
          suggestions.map do |s|
            entry = {
              severity: s[:severity].to_s,
              title: s[:title],
              body: s[:body]
            }
            entry[:migration] = s[:migration] if s[:migration]
            entry[:command] = s[:command] if s[:command]
            entry
          end
        end

        def missing_sql_response
          { error: "Missing required parameter: sql. Provide a SELECT query to explain." }
        end

        def rejected_sql_response(sql)
          keyword = sql.match(DML_PATTERN)&.captures&.first&.upcase
          { error: "SQL rejected: contains #{keyword}. Only SELECT statements are allowed. " \
                   "DML inside CTEs (WITH ... DELETE/INSERT/UPDATE) is also rejected because " \
                   "EXPLAIN ANALYZE executes the query." }
        end

        def error_response(message)
          { error: message }
        end
      end

      ToolRegistry.register(ExplainQuery)
    end
  end
end
