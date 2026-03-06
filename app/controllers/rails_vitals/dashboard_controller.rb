module RailsVitals
  class DashboardController < ApplicationController
    def index
      @records = RailsVitals.store.all.reverse
      @total   = @records.size
      @avg_score     = average(@records, :score)
      @avg_queries   = average(@records, :total_query_count)
      @avg_db_time   = average(@records, :total_db_time_ms)
      @top_offenders = top_offenders(@records)
      @health_trend       = health_trend_data(@records)
      @score_distribution = score_distribution_data(@records)
      @query_volume       = query_volume_data(@records)
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

    def health_trend_data(records)
      records.first(10).map do |r|
        [ r.endpoint, r.score ]
      end
    end

    def score_distribution_data(records)
      {
        "Healthy (90-100)"   => records.count { |r| r.score >= 90 },
        "Acceptable (70-89)" => records.count { |r| (70..89).include?(r.score) },
        "Warning (50-69)"    => records.count { |r| (50..69).include?(r.score) },
        "Critical (0-49)"    => records.count { |r| r.score < 50 }
      }
    end

    def query_volume_data(records)
      records.first(10).each_with_index.map do |r, i|
        [ "##{i + 1} #{r.endpoint}", { queries: r.total_query_count, db_time: r.total_db_time_ms.round(1) } ]
      end
    end
  end
end
