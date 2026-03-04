module RailsVitals
  module Scorers
    class BaseScorer
      HEALTHY    = (90..100)
      ACCEPTABLE = (70..89)
      WARNING    = (50..69)
      CRITICAL   = (0..49)

      def initialize(collector)
        @collector = collector
      end

      # Returns a score between 0 and 100
      def score
        raise NotImplementedError, "#{self.class} must implement #score"
      end

      private

      def clamp(value)
        value.clamp(0, 100)
      end
    end
  end
end
