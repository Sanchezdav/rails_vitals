module RailsVitals
  class NPlusOnesController < ApplicationController
    def index
      records    = RailsVitals.store.all
      Rails.logger.debug "ALL RECORDS: #{records}"
      @patterns  = Analyzers::NPlusOneAggregator.aggregate(records)
      @total_requests = records.size
    end

    def show
      records   = RailsVitals.store.all
      @patterns = Analyzers::NPlusOneAggregator.aggregate(records)
      @pattern  = @patterns.find { |p| pattern_id(p) == params[:id] }

      return render plain: "Pattern not found", status: :not_found unless @pattern

      @affected_requests = records.select do |r|
        r.n_plus_one_patterns.any? do |sql, count|
          normalize_sql(sql) == @pattern[:pattern]
        end
      end

      @estimated_saving_ms     = (@pattern[:occurrences] * 0.5).round(1)
      @avg_saving_per_request  = @affected_requests.size > 0 ?
        (@estimated_saving_ms / @affected_requests.size).round(1) : 0
    end

    private

    def pattern_id(pattern)
      Digest::MD5.hexdigest(pattern[:pattern])[0..7]
    end
    helper_method :pattern_id

    def normalize_sql(sql)
      sql
        .gsub(/\b\d+\b/, "?")
        .gsub(/'[^']*'/, "?")
        .gsub(/\s+/, " ")
        .strip
    end
  end
end
