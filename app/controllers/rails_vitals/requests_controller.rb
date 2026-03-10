module RailsVitals
  class RequestsController < ApplicationController
    def index
      @records = RailsVitals.store.all.reverse
      @records = filter(@records)
    end

    def show
      @record = RailsVitals.store.find(params[:id])
      render plain: "Request not found", status: :not_found unless @record

      @query_dna = @record.queries.map do |q|
        {
          query: q,
          dna: Analyzers::SqlTokenizer.tokenize(q[:sql], all_queries: @record.queries)
        }
      end
    end

    private

    def filter(records)
      if params[:endpoint].present?
        records = records.select { |r| r.endpoint == params[:endpoint] }
      end

      if params[:score].present?
        records = case params[:score]
        when "critical"   then records.select { |r| r.score < 50 }
        when "warning"    then records.select { |r| (50..69).include?(r.score) }
        when "acceptable" then records.select { |r| (70..89).include?(r.score) }
        when "healthy"    then records.select { |r| r.score >= 90 }
        else records
        end
      end

      if params[:n_plus_one].present?
        records = records.select { |r| r.n_plus_one_patterns.any? }
      end

      records
    end
  end
end
