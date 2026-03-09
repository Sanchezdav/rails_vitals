module RailsVitals
  class ModelsController < ApplicationController
    def index
      records      = RailsVitals.store.all
      @breakdown   = build_breakdown(records)
      @total_requests = records.size
    end

    private

    def build_breakdown(records)
      model_data = Hash.new do |h, k|
        h[k] = {
          query_count:    0,
          total_time_ms:  0.0,
          endpoints:      Hash.new(0),
          callbacks:      Hash.new(0)
        }
      end

      records.each do |record|
        # Query-based data
        record.queries.each do |q|
          model = extract_model(q[:sql])
          next unless model

          model_data[model][:query_count]   += 1
          model_data[model][:total_time_ms] += q[:duration_ms]
          model_data[model][:endpoints][record.endpoint] += 1
        end

        # Callback data as secondary signal
        record.callbacks.each do |cb|
          model_data[cb[:model]][:callbacks][cb[:kind].to_s] += 1
        end
      end

      model_data
        .map do |model, data|
          count = data[:query_count]
          {
            model:         model,
            query_count:   count,
            total_time_ms: data[:total_time_ms].round(1),
            avg_time_ms:   count > 0 ? (data[:total_time_ms] / count).round(2) : 0,
            endpoints:     data[:endpoints].sort_by { |_, v| -v }.to_h,
            callbacks:     data[:callbacks].sort_by { |_, v| -v }.to_h
          }
        end
        .sort_by { |row| -row[:total_time_ms] }
    end

    def extract_model(sql)
      # Extract table name from common SQL patterns
      match = sql.match(/(?:FROM|INTO|UPDATE|JOIN)\s+"?(\w+)"?/i)
      return nil unless match

      table = match[1]
      return nil if table.start_with?("pg_", "information_schema")

      # Convert table name to model name
      table.classify rescue nil
    end
  end
end
