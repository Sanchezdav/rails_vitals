module RailsVitals
  module Analyzers
    class NPlusOneAggregator
      def self.aggregate(records)
        pattern_data = Hash.new do |h, k|
          h[k] = {
            pattern:      k,
            occurrences:  0,
            endpoints:    Hash.new(0),
            table:        nil,
            foreign_key:  nil
          }
        end

        records.each do |record|
          next if record.n_plus_one_patterns.empty?

          record.n_plus_one_patterns.each do |sql, count|
            normalized = normalize(sql)
            Rails.logger.debug "Processing SQL: #{sql} → normalized: #{normalized}"

            pattern_data[normalized][:occurrences] += count
            pattern_data[normalized][:endpoints][record.endpoint] += 1
            pattern_data[normalized][:table]       ||= extract_table(sql)
            pattern_data[normalized][:foreign_key] ||= extract_foreign_key(sql)
          end
        end

        pattern_data
          .values
          .sort_by { |p| -p[:occurrences] }
          .map do |p|
            p[:endpoints] = p[:endpoints].to_h
            p.merge(fix_suggestion: build_suggestion(p))
          end
      end

      private

      def self.normalize(sql)
        sql
          .gsub('\\"', '"')      # unescape stored escaped quotes
          .gsub(/\b\d+\b/, "?")
          .gsub(/'[^']*'/, "?")
          .gsub(/\s+/, " ")
          .strip
      end

      def self.extract_table(sql)
        clean = sql.gsub('\\"', '"')
        clean.match(/FROM\s+"?(\w+)"?/i)&.captures&.first
      end

      def self.extract_foreign_key(sql)
        clean = sql.gsub('\\"', '"')
        clean.match(/WHERE\s+"?\w+"?\."?(\w+_id)"\s*=/i)&.captures&.first
      end

      def self.build_suggestion(pattern)
        table       = pattern[:table]
        foreign_key = pattern[:foreign_key]

        return generic_suggestion(table) unless table && foreign_key

        # Map foreign_key back to association
        owner_model = infer_owner_model(foreign_key)
        assoc_name  = infer_association(table, foreign_key)

        if owner_model && assoc_name
          {
            code:        "#{owner_model}.includes(:#{assoc_name})",
            description: "Eager load :#{assoc_name} on #{owner_model} to eliminate this N+1",
            owner:       owner_model,
            association: assoc_name
          }
        else
          generic_suggestion(table)
        end
      end

      def self.infer_owner_model(foreign_key)
        # foreign_key = "user_id" → owner is "User"
        foreign_key.sub(/_id$/, "").classify
      end

      def self.infer_association(table, foreign_key)
        # table = "posts", foreign_key = "user_id"
        # → association :posts on User
        owner_class_name = foreign_key.sub(/_id$/, "").classify

        begin
          owner_class = owner_class_name.constantize
          return nil unless owner_class < ActiveRecord::Base

          # Find association on owner that points to this table
          assoc = owner_class.reflect_on_all_associations.find do |r|
            r.klass.table_name == table rescue false
          end

          assoc&.name
        rescue NameError
          nil
        end
      end

      def self.generic_suggestion(table)
        {
          code:        "includes(:#{table&.singularize})",
          description: "Use includes(), eager_load(), or preload() to batch this query",
          owner:       nil,
          association: table&.singularize
        }
      end
    end
  end
end
