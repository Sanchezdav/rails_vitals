module RailsVitals
  module Scorers
    class CompositeScorer < BaseScorer
      # Weights will grow as we add more scorers
      WEIGHTS = {
        query:      0.40,
        n_plus_one: 0.60
      }.freeze

      def score
        clamp(
          (QueryScorer.new(@collector).score     * WEIGHTS[:query]).round +
          (NPlusOneScorer.new(@collector).score  * WEIGHTS[:n_plus_one]).round
        )
      end

      def label
        case score
        when BaseScorer::HEALTHY    then "Healthy"
        when BaseScorer::ACCEPTABLE then "Acceptable"
        when BaseScorer::WARNING    then "Warning"
        else                             "Critical"
        end
      end

      def color
        case score
        when BaseScorer::HEALTHY    then "green"
        when BaseScorer::ACCEPTABLE then "blue"
        when BaseScorer::WARNING    then "amber"
        else                             "red"
        end
      end
    end
  end
end
