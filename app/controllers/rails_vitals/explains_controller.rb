module RailsVitals
  class ExplainsController < ApplicationController
    def show
      @record = RailsVitals.store.find(params[:request_id])
      return render plain: "Request not found", status: :not_found unless @record

      @query_index = params[:query_index].to_i
      query = @record.queries[@query_index]
      return render plain: "Query not found", status: :not_found unless query

      @sql = query[:sql]
      @binds = query[:binds] || []
      @result = Analyzers::ExplainAnalyzer.analyze(@sql, binds: @binds)
    end
  end
end
