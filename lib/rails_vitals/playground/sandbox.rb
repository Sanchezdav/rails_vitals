module RailsVitals
  module Playground
    class Sandbox
      BLOCKED_PATTERNS = [
        /\b(insert|update|delete|destroy|drop|truncate|create|alter)\b/i,
        /\.save/i, /\.save!/i, /\.update/i, /\.delete/i,
        /\.destroy/i, /`/,
        /\.connection\b/i, /\.execute\b/i, /\.exec\b/i,
        /\.send\b/i, /\.public_send\b/i, /\.__send__\b/i,
        /\.send_data\b/i, /\.open\b/i,
        /\.instance_eval\b/i, /\.class_eval\b/i, /\.module_eval\b/i,
        /\.define_method\b/i, /\.method_missing\b/i,
        /\bsystem\b/i, /\beval\b/i, /\bfork\b/i, /\bspawn\b/i,
        /\bIO\b/i, /\bFile\b/i, /\bThread\b/i, /\bProcess\b/i
      ].freeze

      SAFE_EXPRESSION_PATTERN = /\A[a-zA-Z0-9_\.\s\(\),:\[\]{}'"!?=<>|&*+\-\/\\%]+\z/

      ASSOCIATION_NAME_PATTERN = /\A[a-zA-Z_][a-zA-Z0-9_]*\z/

      DEFAULT_LIMIT = 100

      Result = Struct.new(
        :queries, :query_count, :duration_ms,
        :error, :model_name, :record_count,
        :score, :n1_patterns,
        keyword_init: true
      )

      def self.run(expression, access_associations: [])
        return blocked_result("No expression provided") if expression.blank?

        expression = expression.gsub(/#[^\n]*/, "").strip
        return blocked_result("No expression provided") if expression.blank?

        return blocked_result(
          "Expression contains invalid characters."
        ) unless expression.match?(SAFE_EXPRESSION_PATTERN)

        BLOCKED_PATTERNS.each do |pattern|
          return blocked_result(
            "Expression contains blocked operation. " \
            "The Playground is read-only — no writes permitted."
          ) if expression.match?(pattern)
        end

        access_associations = access_associations.select do |name|
          name.to_s.match?(ASSOCIATION_NAME_PATTERN)
        end

        model_name = extract_model_name(expression)
        return blocked_result(
          "Could not detect model from expression. " \
          "Start your query with a model name e.g. Post.includes(:likes)"
        ) unless model_name

        model = safe_constantize(model_name)
        return blocked_result(
          "Unknown model: #{model_name}. " \
          "Available models: #{available_models.join(', ')}"
        ) unless model

        queries = []
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
          next if RailsVitals::Notifications::Subscriber.internal_query?(payload[:sql])

          queries << {
            sql: payload[:sql],
            duration_ms: (payload[:duration].to_f / 1000).round(3)
          }
        end

        begin
          Timeout.timeout(2) do
            relation = build_relation(expression, model)
            relation = apply_limit(relation)
            records = relation.load

            # Simulate association access — triggers N+1 if not eager loaded
            if access_associations.any?
              records.each do |record|
                access_associations.each do |assoc|
                  next unless record.class.reflect_on_association(assoc.to_sym)
                  assoc_value = record.public_send(assoc)
                  # Force load if it's a relation
                  assoc_value.load if assoc_value.respond_to?(:load)
                end
              end
            end
          end
        rescue Timeout::Error
          return blocked_result("Query timed out after 2 seconds.")
        rescue => e
          return blocked_result("Execution error: #{e.message}")
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end

        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
        n1_patterns = detect_n1(queries)
        score = project_score(queries.size, n1_patterns.size)

        Result.new(
          queries: queries,
          query_count: queries.size,
          duration_ms: duration_ms,
          error: nil,
          model_name: model_name,
          record_count: DEFAULT_LIMIT,
          score: score,
          n1_patterns: n1_patterns
        )
      rescue => e
        blocked_result("Unexpected error: #{e.message}")
      end

      def self.associations_for(model_name)
        model = safe_constantize(model_name)
        return [] unless model

        model.reflect_on_all_associations.map { |r| r.name.to_s }.sort
      rescue
        []
      end

      def self.extract_model_name(expression)
        match = expression.match(/\A([A-Z][A-Za-z0-9]*)/)
        match ? match[1] : nil
      end

      private

      def self.safe_constantize(name)
        return nil unless name.match?(/\A[A-Z][A-Za-z0-9:]*\z/)

        klass = name.constantize
        return nil unless klass < ActiveRecord::Base

        klass
      rescue NameError
        nil
      end

      def self.build_relation(expression, model)
        chain_str = expression
          .sub(/\A#{Regexp.escape(model.name)}\s*\.?\s*/, "")
          .strip

        return model.all if chain_str.blank?

        SafeChainBuilder.build(chain_str, model)
      rescue SafeChainBuilder::ParseError => e
        raise "Expression error: #{e.message}"
      end

      def self.apply_limit(relation)
        # Only apply default limit if no limit already set
        if relation.limit_value.nil?
          relation.limit(DEFAULT_LIMIT)
        else
          relation
        end
      end

      def self.detect_n1(queries)
        normalized = queries.map do |q|
          q[:sql]
            .gsub(/\b\d+\b/, "?")
            .gsub(/'[^']*'/, "?")
            .gsub(/\bIN\s*\([^)]+\)/, "IN (?)")
            .downcase.strip
        end

        normalized
          .tally
          .select { |_, count| count > 1 }
          .map { |sql, count| { pattern: sql, count: count } }
      end

      def self.project_score(query_count, n1_count)
        config = RailsVitals.config
        query_score = score_queries(query_count, config)
        n1_score = score_n1(n1_count)
        (query_score * 0.40 + n1_score * 0.60).round
      end

      def self.score_queries(count, config)
        return 100 if count <= config.query_warn_threshold
        return 0   if count >= config.query_critical_threshold

        range = config.query_critical_threshold - config.query_warn_threshold
        (100 - ((count - config.query_warn_threshold).to_f / range * 100)).round
      end

      def self.score_n1(count)
        Scorers::NPlusOneScorer.score_for(count)
      end

      def self.blocked_result(message)
        Result.new(
          queries: [], query_count: 0, duration_ms: 0,
          error: message, model_name: nil, record_count: 0,
          score: nil, n1_patterns: []
        )
      end

      def self.available_models
        ActiveRecord::Base.descendants
          .reject(&:abstract_class?)
          .reject { |m| m.name&.start_with?("RailsVitals") }
          .select { |m| m.table_exists? rescue false }
          .map(&:name)
          .sort
      end
    end
  end
end
