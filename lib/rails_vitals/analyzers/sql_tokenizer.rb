module RailsVitals
  module Analyzers
    class SqlTokenizer
      TOKEN_DEFINITIONS = [
        {
          type:        :select_star,
          pattern:     /\bSELECT\s+\*\b/i,
          label:       "SELECT *",
          color:       "#4299e1",
          risk:        :warning,
          explanation: "Fetches all columns from the table. In Rails this is the default " \
                       "behavior of Model.all and most queries. Can be wasteful when you " \
                       "only need specific attributes. Use .select(:id, :name) to fetch " \
                       "only what you need, especially on wide tables."
        },
        {
          type:        :select,
          pattern:     /\bSELECT\b(?!\s+\*)/i,
          label:       "SELECT",
          color:       "#4299e1",
          risk:        :healthy,
          explanation: "Fetches specific columns. More efficient than SELECT * when your " \
                       "table has many columns or large text/json fields you don't need."
        },
        {
          type:        :count,
          pattern:     /\bCOUNT\s*\(/i,
          label:       "COUNT(*)",
          color:       "#ed8936",
          risk:        :warning,
          explanation: "Counts rows matching the condition. When this appears in a loop " \
                       "(N+1 pattern), Rails fires one COUNT query per record. The fix is " \
                       "a counter cache column or loading the association and calling .size " \
                       "which uses the already-loaded records instead of hitting the DB."
        },
        {
          type:        :aggregation,
          pattern:     /\b(SUM|AVG|MIN|MAX)\s*\(/i,
          label:       "AGGREGATE",
          color:       "#ed8936",
          risk:        :warning,
          explanation: "Aggregation function (SUM/AVG/MIN/MAX). Like COUNT, these are " \
                       "dangerous in loops. Each call fires a separate query. Consider " \
                       "loading the association once and using Ruby's .sum/.min/.max on " \
                       "the already-loaded collection instead."
        },
        {
          type:        :from,
          pattern:     /\bFROM\s+"?(\w+)"?/i,
          label:       "FROM",
          color:       "#68d391",
          risk:        :healthy,
          explanation: "Identifies which table (and therefore which ActiveRecord model) " \
                       "is being queried. In an N+1, you'll see the same FROM table " \
                       "repeated many times, once per parent record."
        },
        {
          type:        :where_fk,
          pattern:     /\bWHERE\s+.*\w+_id\s*=/i,
          label:       "WHERE fk =",
          color:       "#fc8181",
          risk:        :danger,
          explanation: "WHERE condition on a foreign key with a single value. This is " \
                       "the N+1 signature, loading one associated record at a time. " \
                       "When you see this pattern repeated, it means Rails is fetching " \
                       "records individually instead of in batch. The fix is includes() " \
                       "which replaces this with a single WHERE fk IN (...) query."
        },
        {
          type:        :where,
          pattern:     /\bWHERE\b/i,
          label:       "WHERE",
          color:       "#f6ad55",
          risk:        :neutral,
          explanation: "Filters rows by condition. Efficient when the condition column " \
                       "has an index. Slow when it doesn't. DB engine will scan every " \
                       "row in the table (Sequential Scan). Check the EXPLAIN output to " \
                       "verify an index is being used."
        },
        {
          type:        :where_in,
          pattern:     /\bIN\s*\(/i,
          label:       "IN (...)",
          color:       "#68d391",
          risk:        :healthy,
          explanation: "Batch lookup fetches multiple records in one query using a list " \
                       "of values. This is what eager loading (includes/preload) generates " \
                       "instead of repeated WHERE fk = ? queries. Seeing IN (...) means " \
                       "your associations are being loaded efficiently."
        },
        {
          type:        :inner_join,
          pattern:     /\bINNER\s+JOIN\b/i,
          label:       "INNER JOIN",
          color:       "#9f7aea",
          risk:        :neutral,
          explanation: "Combines rows from two tables where the join condition matches. " \
                       "In Rails this is what .joins() generates. Records without a " \
                       "matching association are excluded from results. Note: .joins() " \
                       "does NOT load the association, use .includes() if you need " \
                       "to access associated data."
        },
        {
          type:        :left_join,
          pattern:     /\bLEFT\s+(OUTER\s+)?JOIN\b/i,
          label:       "LEFT JOIN",
          color:       "#9f7aea",
          risk:        :neutral,
          explanation: "Like INNER JOIN but keeps all rows from the left table even " \
                       "when there's no matching row on the right. In Rails this is " \
                       "what .eager_load() and .left_joins() generate. Use when you " \
                       "need to include records that have no associated data."
        },
        {
          type:        :order,
          pattern:     /\bORDER\s+BY\b/i,
          label:       "ORDER BY",
          color:       "#76e4f7",
          risk:        :warning,
          explanation: "Sorts results by a column. Fast when sorting on an indexed " \
                       "column. Slow when sorting on an unindexed column. DB engine " \
                       "must sort all matching rows in memory. Default Rails scopes " \
                       "often add ORDER BY created_at DESC, make sure created_at " \
                       "has an index if your table is large."
        },
        {
          type:        :limit,
          pattern:     /\bLIMIT\s+\d+/i,
          label:       "LIMIT",
          color:       "#a0aec0",
          risk:        :healthy,
          explanation: "Restricts the number of rows returned. Always use LIMIT in " \
                       "production feeds and lists, never load unbounded data. " \
                       "Note: LIMIT with OFFSET becomes slower as OFFSET grows " \
                       "because DB engine must scan and discard all preceding rows."
        },
        {
          type:        :offset,
          pattern:     /\bOFFSET\s+\d+/i,
          label:       "OFFSET",
          color:       "#fc8181",
          risk:        :warning,
          explanation: "Skips N rows before returning results. Common in pagination " \
                       "(page 2, page 3...). The hidden cost: DB engine must read " \
                       "and discard all rows before the offset, at page 100 with " \
                       "20 per page, it scans 2,000 rows to return 20. Use " \
                       "cursor-based pagination (WHERE id > last_id) for large datasets."
        },
        {
          type:        :group_by,
          pattern:     /\bGROUP\s+BY\b/i,
          label:       "GROUP BY",
          color:       "#76e4f7",
          risk:        :neutral,
          explanation: "Groups rows sharing a value and applies aggregate functions " \
                       "per group. Common with COUNT, SUM, AVG. Used in Rails with " \
                       ".group(:column). Consider a counter cache column if you're " \
                       "grouping and counting frequently, it replaces a GROUP BY " \
                       "query with a single column read."
        }
      ].freeze

      COMPLEXITY_RULES = [
        { tokens: [ :left_join, :inner_join ], points: 2 },
        { tokens: [ :where_fk ],              points: 3 },
        { tokens: [ :count, :aggregation ],   points: 2 },
        { tokens: [ :offset ],                points: 2 },
        { tokens: [ :group_by ],              points: 1 },
        { tokens: [ :order ],                 points: 1 }
      ].freeze

      Result = Struct.new(:tokens, :complexity, :complexity_label,
                          :risk, :repetition_count, :repetition_bar,
                          keyword_init: true)

      def self.tokenize(sql, all_queries: [])
        matched = TOKEN_DEFINITIONS.select { |td| sql.match?(td[:pattern]) }

        complexity = calculate_complexity(matched)
        risk = highest_risk(matched)
        repetition = calculate_repetition(sql, all_queries)

        Result.new(
          tokens:           matched,
          complexity:       complexity,
          complexity_label: complexity_label(complexity),
          risk:             risk,
          repetition_count: repetition,
          repetition_bar:   repetition_bar(repetition, all_queries.size)
        )
      end

      private

      def self.calculate_complexity(matched_tokens)
        types = matched_tokens.map { |t| t[:type] }
        base = 1
        COMPLEXITY_RULES.each do |rule|
          base += rule[:points] if (rule[:tokens] & types).any?
        end
        base.clamp(1, 10)
      end

      def self.complexity_label(score)
        case score
        when 1..2 then { label: "Simple",   color: "#68d391" }
        when 3..5 then { label: "Moderate", color: "#f6ad55" }
        else           { label: "Complex",  color: "#fc8181" }
        end
      end

      def self.highest_risk(matched_tokens)
        risks = { healthy: 0, neutral: 1, warning: 2, danger: 3 }
        matched_tokens.max_by { |t| risks[t[:risk]] || 0 }&.dig(:risk) || :healthy
      end

      def self.calculate_repetition(sql, all_queries)
        return 0 if all_queries.empty?

        normalized = normalize(sql)
        all_queries.count { |q| normalize(q[:sql]) == normalized }
      end

      def self.repetition_bar(count, total)
        return [] if count <= 1

        filled = total > 0 ? ((count.to_f / total) * 20).ceil : 0
        { count: count, filled: filled, empty: 20 - filled }
      end

      def self.normalize(sql)
        sql.gsub(/\b\d+\b/, "?")
           .gsub(/'[^']*'/, "?")
           .gsub(/\s+/, " ")
           .strip
           .downcase
      end
    end
  end
end
