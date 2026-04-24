module RailsVitals
  module Scorers
    class NPlusOneScorer < BaseScorer
      # Minimum times the same query must repeat to be flagged
      REPEAT_THRESHOLD = 3

      def self.score_for(pattern_count)
        [ 100 - (pattern_count * 25), 0 ].max
      end

      def score
        self.class.score_for(n_plus_one_count)
      end

      def n_plus_one_patterns
        query_fingerprints
          .select { |_fingerprint, count| count >= REPEAT_THRESHOLD }
      end

      private

      def n_plus_one_count
        n_plus_one_patterns.size
      end

      def query_fingerprints
        @collector.queries
          .select { |q| q.is_a?(Hash) && q[:sql].is_a?(String) }
          .map { |q| normalize(q[:sql]) }
          .tally
      end

      # Strip values to compare query structure, not data
      def normalize(sql)
        sql
          .gsub(/\d+/, "?")
          .gsub(/'[^']*'/, "?")
          .gsub(/\s+/, " ")
          .strip
          .downcase
      end
    end
  end
end
