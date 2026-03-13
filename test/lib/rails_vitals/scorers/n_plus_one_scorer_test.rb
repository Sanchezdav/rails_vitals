require "test_helper"

class RailsVitalsNPlusOneScorerTest < ActiveSupport::TestCase
  test "#n_plus_one_patterns returns Hash<String, Integer> for repeated normalized SQL at threshold" do
    collector = build_collector(
      queries: [
        build_query(sql: "SELECT * FROM users WHERE users.id = 1", duration_ms: 3.2),
        build_query(sql: "SELECT * FROM users WHERE users.id = 2", duration_ms: 2.8),
        build_query(sql: "SELECT * FROM users WHERE users.id = 3", duration_ms: 2.9),
        build_query(sql: "SELECT * FROM posts WHERE posts.id = 1", duration_ms: 5.4)
      ]
    )

    scorer = RailsVitals::Scorers::NPlusOneScorer.new(collector)
    result = scorer.n_plus_one_patterns

    assert_kind_of Hash, result
    assert_equal 1, result.size
    assert_equal 3, result["select * from users where users.id = ?"]
  end

  test "#score returns 100 when no N+1 pattern reaches repeat threshold" do
    collector = build_collector(
      queries: [
        build_query(sql: "SELECT * FROM users WHERE users.id = 1", duration_ms: 3.2),
        build_query(sql: "SELECT * FROM users WHERE users.id = 2", duration_ms: 2.8)
      ]
    )

    scorer = RailsVitals::Scorers::NPlusOneScorer.new(collector)

    assert_equal 100, scorer.score
  end

  test "#score returns clamped score after deducting 25 points per N+1 pattern" do
    collector = build_collector(
      queries: [
        build_query(sql: "SELECT * FROM users WHERE users.id = 1", duration_ms: 1.0),
        build_query(sql: "SELECT * FROM users WHERE users.id = 2", duration_ms: 1.0),
        build_query(sql: "SELECT * FROM users WHERE users.id = 3", duration_ms: 1.0),
        build_query(sql: "SELECT * FROM posts WHERE posts.id = 1", duration_ms: 1.0),
        build_query(sql: "SELECT * FROM posts WHERE posts.id = 2", duration_ms: 1.0),
        build_query(sql: "SELECT * FROM posts WHERE posts.id = 3", duration_ms: 1.0),
        build_query(sql: "SELECT * FROM comments WHERE comments.id = 1", duration_ms: 1.0),
        build_query(sql: "SELECT * FROM comments WHERE comments.id = 2", duration_ms: 1.0),
        build_query(sql: "SELECT * FROM comments WHERE comments.id = 3", duration_ms: 1.0),
        build_query(sql: "SELECT * FROM tags WHERE tags.id = 1", duration_ms: 1.0),
        build_query(sql: "SELECT * FROM tags WHERE tags.id = 2", duration_ms: 1.0),
        build_query(sql: "SELECT * FROM tags WHERE tags.id = 3", duration_ms: 1.0)
      ]
    )

    scorer = RailsVitals::Scorers::NPlusOneScorer.new(collector)

    assert_equal 0, scorer.score
  end
end
