require "test_helper"

class RailsVitalsPlaygroundSandboxTest < ActiveSupport::TestCase
  Sandbox = RailsVitals::Playground::Sandbox

  # ─── extract_model_name ────────────────────────────────────────────────────

  test ".extract_model_name returns CamelCase constant from the start of the expression" do
    assert_equal "User",    Sandbox.extract_model_name("User.all")
    assert_equal "Post",    Sandbox.extract_model_name("Post.where(published: true)")
    assert_equal "MyModel", Sandbox.extract_model_name("MyModel.includes(:tags)")
  end

  test ".extract_model_name strips line comments before extracting the model name" do
    expr = "# find all users\nUser.all"
    assert_equal "User", Sandbox.extract_model_name(expr)
  end

  test ".extract_model_name returns nil when expression starts with a lowercase word" do
    assert_nil Sandbox.extract_model_name("user.all")
    assert_nil Sandbox.extract_model_name("find_by(:name)")
  end

  test ".extract_model_name returns nil when expression is blank or empty" do
    assert_nil Sandbox.extract_model_name("")
    assert_nil Sandbox.extract_model_name("   ")
    assert_nil Sandbox.extract_model_name("# just a comment")
  end

  # ─── run — blocking guard clauses ─────────────────────────────────────────

  test ".run returns Result with error and zero query_count when expression is blank" do
    result = Sandbox.run("")
    assert_equal "No expression provided", result.error
    assert_equal 0,  result.query_count
    assert_equal [], result.queries
    assert_equal [], result.n1_patterns
  end

  test ".run returns Result with error for INSERT expression" do
    result = Sandbox.run("INSERT INTO users VALUES (1)")
    assert_includes result.error, "blocked operation"
    assert_nil result.model_name
  end

  test ".run returns Result with error for UPDATE expression" do
    result = Sandbox.run("UPDATE users SET name = 'x' WHERE id = 1")
    assert_includes result.error, "blocked operation"
  end

  test ".run returns Result with error for DELETE expression" do
    result = Sandbox.run("DELETE FROM users WHERE id = 1")
    assert_includes result.error, "blocked operation"
  end

  test ".run returns Result with error for DROP TABLE expression" do
    result = Sandbox.run("DROP TABLE users")
    assert_includes result.error, "blocked operation"
  end

  test ".run returns Result with error for expression containing .save" do
    result = Sandbox.run("User.first.save")
    assert_includes result.error, "blocked operation"
  end

  test ".run returns Result with error for expression containing .destroy" do
    result = Sandbox.run("User.first.destroy")
    assert_includes result.error, "blocked operation"
  end

  test ".run returns Result with error when model name cannot be extracted from expression" do
    result = Sandbox.run("1 + 1")
    assert_includes result.error, "Could not detect model"
    assert_equal [], result.queries
  end

  test ".run returns Result with error when model constant is not a known ActiveRecord model" do
    result = Sandbox.run("Nonexistent.all")
    assert_includes result.error, "Unknown model"
    assert_includes result.error, "Nonexistent"
  end

  # ─── associations_for ──────────────────────────────────────────────────────

  test ".associations_for returns empty Array when model_name is nil" do
    result = Sandbox.associations_for(nil)
    assert_instance_of Array, result
    assert_equal [], result
  end

  test ".associations_for returns empty Array for an unknown model name string" do
    result = Sandbox.associations_for("Nonexistent")
    assert_instance_of Array, result
    assert_equal [], result
  end

  # ─── detect_n1 ─────────────────────────────────────────────────────────────

  test ".detect_n1 returns empty Array when all query SQL strings are unique" do
    queries = [
      { sql: "SELECT * FROM users WHERE id = 1" },
      { sql: "SELECT * FROM posts WHERE id = 2" }
    ]
    assert_equal [], Sandbox.send(:detect_n1, queries)
  end

  test ".detect_n1 returns Array<Hash> with pattern and count when the same normalized query appears more than once" do
    queries = [
      { sql: "SELECT * FROM comments WHERE post_id = 1" },
      { sql: "SELECT * FROM comments WHERE post_id = 2" },
      { sql: "SELECT * FROM comments WHERE post_id = 3" }
    ]
    result = Sandbox.send(:detect_n1, queries)

    assert_equal 1, result.size
    assert_equal 3, result.first[:count]
    assert_includes result.first[:pattern], "comments"
    assert_includes result.first[:pattern], "?"
  end

  test ".detect_n1 normalizes IN clause so lists with different values produce the same pattern" do
    queries = [
      { sql: "SELECT * FROM tags WHERE id IN (1, 2, 3)" },
      { sql: "SELECT * FROM tags WHERE id IN (4, 5)" }
    ]
    result = Sandbox.send(:detect_n1, queries)

    assert_equal 1, result.size
    assert_equal 2, result.first[:count]
  end

  test ".detect_n1 normalizes string literals so different values match the same pattern" do
    queries = [
      { sql: "SELECT * FROM users WHERE email = 'alice@example.com'" },
      { sql: "SELECT * FROM users WHERE email = 'bob@example.com'" }
    ]
    result = Sandbox.send(:detect_n1, queries)

    assert_equal 1, result.size
    assert_equal 2, result.first[:count]
  end

  # ─── score_n1 ──────────────────────────────────────────────────────────────

  test ".score_n1 returns 100 when n1_count is 0" do
    assert_equal 100, Sandbox.send(:score_n1, 0)
  end

  test ".score_n1 returns 75 when n1_count is 1" do
    assert_equal 75, Sandbox.send(:score_n1, 1)
  end

  test ".score_n1 returns 50 when n1_count is 2" do
    assert_equal 50, Sandbox.send(:score_n1, 2)
  end

  test ".score_n1 returns 0 and does not go negative when n1_count is 4 or more" do
    assert_equal 0, Sandbox.send(:score_n1, 4)
    assert_equal 0, Sandbox.send(:score_n1, 10)
  end

  # ─── score_queries ─────────────────────────────────────────────────────────

  test ".score_queries returns 100 when query count is at or below warn threshold" do
    with_rails_vitals_config(query_warn_threshold: 10, query_critical_threshold: 25) do
      assert_equal 100, Sandbox.send(:score_queries, 0,  RailsVitals.config)
      assert_equal 100, Sandbox.send(:score_queries, 10, RailsVitals.config)
    end
  end

  test ".score_queries returns 0 when query count is at or above critical threshold" do
    with_rails_vitals_config(query_warn_threshold: 10, query_critical_threshold: 25) do
      assert_equal 0, Sandbox.send(:score_queries, 25, RailsVitals.config)
      assert_equal 0, Sandbox.send(:score_queries, 50, RailsVitals.config)
    end
  end

  test ".score_queries returns interpolated Integer between 0 and 100 when count is between thresholds" do
    with_rails_vitals_config(query_warn_threshold: 10, query_critical_threshold: 25) do
      # 15 queries: (100 - ((15-10)/15.0*100)).round = 67
      assert_equal 67, Sandbox.send(:score_queries, 15, RailsVitals.config)
    end
  end

  # ─── project_score ─────────────────────────────────────────────────────────

  test ".project_score returns 100 when query count is at warn threshold and there are no n1 patterns" do
    with_rails_vitals_config(query_warn_threshold: 10, query_critical_threshold: 25) do
      assert_equal 100, Sandbox.send(:project_score, 0, 0)
    end
  end

  test ".project_score applies 40/60 weighted combination of query score and n1 score" do
    with_rails_vitals_config(query_warn_threshold: 10, query_critical_threshold: 25) do
      # query_score(0) = 100, score_n1(2) = 50
      # weighted = (100 * 0.40 + 50 * 0.60).round = 70
      assert_equal 70, Sandbox.send(:project_score, 0, 2)
    end
  end

  test ".project_score returns 0 when query count hits critical threshold regardless of n1 count" do
    with_rails_vitals_config(query_warn_threshold: 10, query_critical_threshold: 25) do
      # query_score(25) = 0, n1_score(0) = 100
      # weighted = (0 * 0.40 + 100 * 0.60).round = 60
      assert_equal 60, Sandbox.send(:project_score, 25, 0)
    end
  end
end
