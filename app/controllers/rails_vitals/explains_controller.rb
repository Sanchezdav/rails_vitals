module RailsVitals
  class ExplainsController < ApplicationController
    def show
      sql = params[:sql]
      request_id = params[:request_id]

      if sql.blank?
        return render plain: "No SQL provided", status: :bad_request
      end

      @sql = sql
      @request_id = request_id
      @record = request_id ? RailsVitals.store.find(request_id) : nil
      @result = Analyzers::ExplainAnalyzer.analyze(sql)
    end
  end
end
