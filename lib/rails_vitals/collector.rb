module RailsVitals
  class Collector
    attr_reader :queries, :controller, :action, :http_method,
                :response_status, :duration_ms, :started_at

    def initialize
      @queries        = []
      @controller     = nil
      @action         = nil
      @http_method    = nil
      @response_status = nil
      @duration_ms    = nil
      @started_at     = Time.now
    end

    # Called by the sql.active_record subscriber
    def add_query(sql:, duration_ms:, source:)
      @queries << {
        sql:         sql,
        duration_ms: duration_ms,
        source:      source,
        called_at:   Time.now
      }
    end

    # Called by the process_action.action_controller subscriber
    def finalize!(event)
      @controller      = event.payload[:controller]
      @action          = event.payload[:action]
      @http_method     = event.payload[:method]
      @response_status = event.payload[:status]
      @duration_ms     = event.duration
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

    # Thread-local storage accessors
    def self.current
      Thread.current[:rails_vitals_collector]
    end

    def self.current=(collector)
      Thread.current[:rails_vitals_collector] = collector
    end

    def self.reset!
      Thread.current[:rails_vitals_collector] = nil
    end
  end
end
