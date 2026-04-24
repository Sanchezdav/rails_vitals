module RailsVitals
  module Scorers
    class BaseScorer
      HEALTHY = (90..100)
      ACCEPTABLE = (70..89)
      WARNING = (50..69)
      CRITICAL = (0..49)

      def self.label_for(score)
        case score
        when HEALTHY    then "Healthy"
        when ACCEPTABLE then "Acceptable"
        when WARNING    then "Warning"
        else                 "Critical"
        end
      end

      def self.color_for(score)
        case score
        when HEALTHY    then "green"
        when ACCEPTABLE then "blue"
        when WARNING    then "amber"
        else                 "red"
        end
      end

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
