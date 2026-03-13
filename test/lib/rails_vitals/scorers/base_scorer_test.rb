require "test_helper"

class RailsVitalsBaseScorerTest < ActiveSupport::TestCase
  test "#score returns NotImplementedError in abstract base class" do
    scorer = RailsVitals::Scorers::BaseScorer.new(Object.new)

    assert_raises(NotImplementedError) { scorer.score }
  end

  test "#clamp returns Integer score within 0..100 boundaries" do
    scorer_class = Class.new(RailsVitals::Scorers::BaseScorer) do
      def score
        send(:clamp, -10)
      end

      def high
        send(:clamp, 120)
      end

      def mid
        send(:clamp, 77)
      end
    end

    scorer = scorer_class.new(Object.new)

    assert_equal 0, scorer.score
    assert_equal 100, scorer.high
    assert_equal 77, scorer.mid
  end
end
