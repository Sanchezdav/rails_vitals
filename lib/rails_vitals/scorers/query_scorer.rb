module RailsVitals
  module Scorers
    class QueryScorer < BaseScorer
      def score
        clamp(count_score + time_score)
      end

      private

      def count_score
        count = @collector.total_query_count
        warn_threshold     = RailsVitals.config.query_warn_threshold
        critical_threshold = RailsVitals.config.query_critical_threshold

        if count <= warn_threshold
          50  # full points
        elsif count <= critical_threshold
          # linear decay between warn and critical
          ratio = (count - warn_threshold).to_f / (critical_threshold - warn_threshold)
          (50 * (1 - ratio)).round
        else
          0
        end
      end

      def time_score
        time_ms    = @collector.total_db_time_ms
        warn_ms    = RailsVitals.config.db_time_warn_ms
        critical_ms = RailsVitals.config.db_time_critical_ms

        if time_ms <= warn_ms
          50
        elsif time_ms <= critical_ms
          ratio = (time_ms - warn_ms).to_f / (critical_ms - warn_ms)
          (50 * (1 - ratio)).round
        else
          0
        end
      end
    end
  end
end
