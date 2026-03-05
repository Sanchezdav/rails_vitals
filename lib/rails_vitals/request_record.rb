module RailsVitals
  class RequestRecord
    attr_reader :id, :controller, :action, :http_method,
                :response_status, :duration_ms, :score,
                :label, :color, :queries, :n_plus_one_patterns,
                :recorded_at

    def initialize(collector:, scorer:)
      @id                  = SecureRandom.hex(8)
      @controller          = collector.controller
      @action              = collector.action
      @http_method         = collector.http_method
      @response_status     = collector.response_status
      @duration_ms         = collector.duration_ms
      @queries             = collector.queries
      @score               = scorer.score
      @label               = scorer.label
      @color               = scorer.color
      @n_plus_one_patterns = build_n_plus_one_patterns(scorer)
      @recorded_at         = Time.now
    end

    def endpoint
      "#{@controller}##{@action}"
    end

    def total_query_count
      @queries.size
    end

    def total_db_time_ms
      @queries.sum { |q| q[:duration_ms] }
    end

    def slowest_queries(limit = 3)
      @queries.sort_by { |q| -q[:duration_ms] }.first(limit)
    end

    private

    def build_n_plus_one_patterns(scorer)
      scorer_instance = scorer.is_a?(Scorers::CompositeScorer) ?
        Scorers::NPlusOneScorer.new(scorer.instance_variable_get(:@collector)) :
        nil

      scorer_instance&.n_plus_one_patterns || {}
    end
  end
end
