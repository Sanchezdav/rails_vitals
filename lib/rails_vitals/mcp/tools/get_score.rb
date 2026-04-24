module RailsVitals
  module MCP
    module Tools
      class GetScore < Base
        include Calculable
        TOOL_NAME = "railsvitals_get_score"

        DESCRIPTION = <<~DESC.strip
          Returns the composite health score for the Rails app based on recent requests
          recorded by RailsVitals. Includes a grade, per-component score breakdown
          (query count and N+1 patterns), penalty details, and a projected score that
          shows how much improvement fixing all N+1 patterns would yield.
          Call this first to get a high-level diagnosis before drilling into specifics.
        DESC

        INPUT_SCHEMA = {
          type: "object",
          properties: {}
        }.freeze

        WEIGHTS = Scorers::CompositeScorer::WEIGHTS

        def call(_params)
          records = RailsVitals.store.all

          return no_data_response if records.empty?

          overall_score = average(records, :score)

          {
            overall_score: overall_score,
            grade: grade_for(overall_score),
            color: color_for(overall_score),
            requests_analyzed: records.size,
            score_breakdown: build_score_breakdown(records),
            penalties: build_penalties(records),
            projected_score_if_n1_fixed: projected_score(records)
          }
        end

        private

        def no_data_response
          {
            overall_score: nil,
            grade: "No data",
            color: "grey",
            requests_analyzed: 0,
            message: "No requests recorded yet. Make some requests to the app first."
          }
        end

        def build_score_breakdown(records)
          avg_n1 = avg_n1_score(records)
          avg_query = avg_query_score(records)

          {
            query_component: {
              weight: WEIGHTS[:query],
              avg_score: avg_query,
              avg_contribution: (avg_query * WEIGHTS[:query]).round(1)
            },
            n1_component: {
              weight: WEIGHTS[:n_plus_one],
              avg_score: avg_n1,
              avg_contribution: (avg_n1 * WEIGHTS[:n_plus_one]).round(1)
            }
          }
        end

        def build_penalties(records)
          warn_threshold = RailsVitals.config.query_warn_threshold
          db_warn_ms = RailsVitals.config.db_time_warn_ms

          n1_affected = records.select { |r| r.n_plus_one_patterns.any? }
          total_patterns = records.sum { |r| r.n_plus_one_patterns.size }
          unique_patterns = records.flat_map { |r| r.n_plus_one_patterns.keys }.uniq.size

          {
            n1_patterns: {
              requests_affected: n1_affected.size,
              percentage_requests: percentage(n1_affected.size, records.size),
              unique_patterns: unique_patterns,
              total_occurrences: total_patterns
            },
            high_query_count: {
              requests_above_threshold: records.count { |r| r.total_query_count > warn_threshold },
              threshold: warn_threshold
            },
            slow_db_time: {
              requests_above_threshold: records.count { |r| r.total_db_time_ms > db_warn_ms },
              threshold_ms: db_warn_ms
            }
          }
        end

        # What the average composite score would be if every request had zero N+1 patterns.
        # Formula: composite_now = query_contribution + n1_contribution
        #          projected = composite_now - n1_contribution + (100 * WEIGHTS[:n_plus_one])
        def projected_score(records)
          gain_per_record = records.map do |r|
            n1_now = n1_score_for(r)
            ((100 - n1_now) * WEIGHTS[:n_plus_one]).round(1)
          end

          avg_gain = gain_per_record.sum.to_f / gain_per_record.size
          (average(records, :score) + avg_gain).round.clamp(0, 100)
        end

        def n1_score_for(record)
          Scorers::NPlusOneScorer.score_for(record.n_plus_one_patterns.size)
        end

        def avg_n1_score(records)
          (records.sum { |r| n1_score_for(r) }.to_f / records.size).round(1)
        end

        # Back-calculates query score from composite and N+1 scores.
        # composite = (query_score * W_query).round + (n1_score * W_n1).round
        # Approximation is sufficient for AI context.
        def query_score_for(record)
          n1_contribution = (n1_score_for(record) * WEIGHTS[:n_plus_one]).round
          query_contribution = record.score - n1_contribution
          (query_contribution.to_f / WEIGHTS[:query]).round(1).clamp(0, 100)
        end

        def avg_query_score(records)
          (records.sum { |r| query_score_for(r) }.to_f / records.size).round(1)
        end

        def grade_for(score)
          Scorers::BaseScorer.label_for(score)
        end

        def color_for(score)
          Scorers::BaseScorer.color_for(score)
        end
      end

      ToolRegistry.register(GetScore)
    end
  end
end
