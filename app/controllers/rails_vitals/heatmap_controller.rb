module RailsVitals
  class HeatmapController < ApplicationController
    def index
      records   = RailsVitals.store.all
      @heatmap  = build_heatmap(records)
      @total    = records.size
    end

    private

    def build_heatmap(records)
      records
        .group_by(&:endpoint)
        .map do |endpoint, reqs|
          {
            endpoint:         endpoint,
            hits:             reqs.size,
            avg_score:        average(reqs, :score),
            avg_queries:      average(reqs, :total_query_count),
            avg_db_time:      average(reqs, :total_db_time_ms),
            avg_callback_time: average(reqs, :total_callback_time_ms),
            n_plus_one_freq:  n_plus_one_frequency(reqs)
          }
        end
        .sort_by { |row| row[:avg_score] }
    end

    def average(records, method)
      return 0.0 if records.empty?
      (records.sum { |r| r.public_send(method) }.to_f / records.size).round(1)
    end

    def n_plus_one_frequency(reqs)
      reqs_with_n1 = reqs.count { |r| r.n_plus_one_patterns.any? }
      return 0.0 if reqs.empty?
      ((reqs_with_n1.to_f / reqs.size) * 100).round(1)
    end
  end
end
