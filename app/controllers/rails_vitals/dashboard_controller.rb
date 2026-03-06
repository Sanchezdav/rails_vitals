module RailsVitals
  class DashboardController < ApplicationController
    def index
      @records = RailsVitals.store.all.reverse
      @total   = @records.size
      @avg_score     = average(@records, :score)
      @avg_queries   = average(@records, :total_query_count)
      @avg_db_time   = average(@records, :total_db_time_ms)
      @top_offenders = top_offenders(@records)
    end

    private

    def average(records, method)
      return 0 if records.empty?

      (records.sum(&method).to_f / records.size).round(1)
    end

    def top_offenders(records)
      records
        .group_by(&:endpoint)
        .transform_values do |reqs|
          {
            count:          reqs.size,
            avg_score:      average(reqs, :score),
            avg_queries:    average(reqs, :total_query_count),
            avg_db_time_ms: average(reqs, :total_db_time_ms)
          }
        end
        .sort_by { |_, v| v[:avg_score] }
        .first(5)
    end
  end
end
