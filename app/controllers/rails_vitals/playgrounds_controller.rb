module RailsVitals
  class PlaygroundsController < ApplicationController
    def index
      @default_query = default_query
      @default_model = default_model_name
      @available_assocs = associations_for_model(@default_model)
      @prechecked_assocs = prechecked_associations
    end

    def create
      expression = params[:expression].to_s.strip
      clean_expr = clean_expression(expression)
      access_associations = Array(params[:access_associations]).reject(&:blank?)

      result = Playground::Sandbox.run(
        expression,
        access_associations: access_associations
      )

      model_name = Playground::Sandbox.extract_model_name(expression)
      @available_assocs = associations_for_model(model_name)
      @prechecked_assocs = access_associations

      @expression = clean_expr
      @result = result
      @previous = session_previous
      @query_dna = build_dna(result.queries)

      session[:playground_previous] = serialize_result(result, clean_expr, access_associations)

      render :index
    end

    private

    def discover_models
      Analyzers::AssociationMapper.discover_models.map(&:name)
    end

    def worst_n1_pattern
      records = RailsVitals.store.all
      return nil if records.empty?

      Analyzers::NPlusOneAggregator.aggregate(records).first
    end

    def session_previous
      raw = session[:playground_previous]
      return nil unless raw

      JSON.parse(raw, symbolize_names: true)
    rescue
      nil
    end

    def default_model_name
      pattern = worst_n1_pattern
      return discover_models.first unless pattern

      pattern[:fix_suggestion]&.dig(:owner_model) || discover_models.first
    end

    def associations_for_model(model_name)
      return [] unless model_name

      Playground::Sandbox.associations_for(model_name)
    end

    def prechecked_associations
      pattern = worst_n1_pattern
      return [] unless pattern

      # Pre-check the association from the worst N+1 pattern
      table = pattern[:table]
      return [] unless table

      assoc_name = table  # table name is usually the association name
      [ @available_assocs.find { |a| a == assoc_name || a == assoc_name.singularize } ].compact
    end

    def default_query
      pattern = worst_n1_pattern
      return "" unless pattern

      fix = pattern[:fix_suggestion]&.dig(:code)
      return "" unless fix

      "# Worst N+1 detected in your app:\n# Fix: #{fix}\n\n#{fix.split('.').first}.all"
    end

    def serialize_result(result, expression, access_associations = [])
      {
        expression:         expression,
        query_count:        result.query_count,
        score:              result.score,
        duration_ms:        result.duration_ms,
        n1_count:           result.n1_patterns.size,
        access_associations: access_associations,
        error:              result.error
      }.to_json
    end

    def clean_expression(expression)
      expression
        .lines
        .reject { |l| l.strip.start_with?("#") }
        .join
        .strip
    end

    def build_dna(queries)
      queries.map do |q|
        {
          query: q,
          dna:   Analyzers::SqlTokenizer.tokenize(q[:sql], all_queries: queries)
        }
      end
    end
  end
end
