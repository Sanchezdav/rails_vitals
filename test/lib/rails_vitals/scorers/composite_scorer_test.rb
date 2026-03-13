require "test_helper"

class RailsVitalsCompositeScorerTest < ActiveSupport::TestCase
  test "#score returns weighted Integer of QueryScorer 40% and NPlusOneScorer 60%" do
    collector = Object.new
    scorer = RailsVitals::Scorers::CompositeScorer.new(collector)

    query_scorer = Struct.new(:score).new(81)
    n_plus_one_scorer = Struct.new(:score).new(74)

    with_stub(RailsVitals::Scorers::QueryScorer, :new, query_scorer) do
      with_stub(RailsVitals::Scorers::NPlusOneScorer, :new, n_plus_one_scorer) do
        assert_equal 76, scorer.score
      end
    end
  end

  test "#label returns category String based on score ranges" do
    scorer = RailsVitals::Scorers::CompositeScorer.new(Object.new)

    with_stub(scorer, :score, 95) { assert_equal "Healthy", scorer.label }
    with_stub(scorer, :score, 75) { assert_equal "Acceptable", scorer.label }
    with_stub(scorer, :score, 55) { assert_equal "Warning", scorer.label }
    with_stub(scorer, :score, 40) { assert_equal "Critical", scorer.label }
  end

  test "#color returns String token mapped from score ranges" do
    scorer = RailsVitals::Scorers::CompositeScorer.new(Object.new)

    with_stub(scorer, :score, 95) { assert_equal "green", scorer.color }
    with_stub(scorer, :score, 75) { assert_equal "blue", scorer.color }
    with_stub(scorer, :score, 55) { assert_equal "amber", scorer.color }
    with_stub(scorer, :score, 40) { assert_equal "red", scorer.color }
  end
end
