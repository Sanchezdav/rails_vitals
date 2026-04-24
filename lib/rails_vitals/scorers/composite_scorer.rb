module RailsVitals
  module Scorers
    class CompositeScorer < BaseScorer
      # Weights will grow as we add more scorers
      WEIGHTS = {
        query: 0.40,
        n_plus_one: 0.60
      }.freeze

      def score
        clamp(
          (QueryScorer.new(@collector).score * WEIGHTS[:query]).round +
          (NPlusOneScorer.new(@collector).score * WEIGHTS[:n_plus_one]).round
        )
      end

      def label
        BaseScorer.label_for(score)
      end

      def color
        BaseScorer.color_for(score)
      end
    end
  end
end
