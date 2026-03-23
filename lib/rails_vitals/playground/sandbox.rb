module RailsVitals
  module Playground
    class Sandbox
      ALLOWED_METHODS = %w[
        all where select limit offset order group
        includes preload eager_load joins left_joins
        find find_by first last count sum average
        pluck distinct having references unscoped
      ].freeze

      BLOCKED_PATTERNS = [
        /\b(insert|update|delete|destroy|drop|truncate|create|alter)\b/i,
        /\.save/i, /\.save!/i, /\.update/i, /\.delete/i,
        /\.destroy/i, /`/
      ].freeze

      DEFAULT_LIMIT = 100

      Result = Struct.new(
        :queries, :query_count, :duration_ms,
        :error, :model_name, :record_count,
        :score, :n1_patterns,
        keyword_init: true
      )

      def self.run(expression, access_associations: [])
        return blocked_result("No expression provided") if expression.blank?

        BLOCKED_PATTERNS.each do |pattern|
          return blocked_result(
            "Expression contains blocked operation. " \
            "The Playground is read-only — no writes permitted."
          ) if expression.match?(pattern)
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
            records  = relation.load

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
        # Strip comments first
        clean = expression.gsub(/#[^\n]*/, "").strip
        # First word before a dot or whitespace — must look like a constant (CamelCase)
        match = clean.match(/\A([A-Z][A-Za-z0-9]*)/)
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
        # Parse "Post.includes(:likes).where(published: true).limit(10)"
        # Strip the model name prefix if present
        chain_str = expression
          .sub(/\A#{Regexp.escape(model.name)}\s*\.?\s*/, "")
          .strip

        return model.all if chain_str.blank?

        # Build the chain by safe eval within a controlled binding
        # Only the model constant is exposed, no access to app globals
        sandbox_binding = build_binding(model)
        relation = eval(chain_str, sandbox_binding) # rubocop:disable Security/Eval

        unless relation.is_a?(ActiveRecord::Relation)
          raise "Expression must return an ActiveRecord::Relation"
        end

        relation
      end

      def self.build_binding(model)
        # Create a minimal binding with only the model exposed
        ctx = Object.new
        ctx.define_singleton_method(:relation) { model.all }
        ctx.instance_eval { binding }
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
        [ 100 - (count * 25), 0 ].max
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
