module RailsVitals
  module Notifications
    class Subscriber
      def self.attach
        attach_sql_subscriber
        attach_action_controller_subscriber
      end

      private_class_method def self.attach_sql_subscriber
        ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
          next unless RailsVitals.config.enabled
          next if (collector = RailsVitals::Collector.current).nil?
          next if internal_query?(event.payload[:sql])

          collector.add_query(
            sql:         event.payload[:sql],
            duration_ms: event.duration,
            source:      extract_source(event.payload[:binds])
          )
        end
      end

      private_class_method def self.attach_action_controller_subscriber
        ActiveSupport::Notifications.subscribe("process_action.action_controller") do |event|
          next unless RailsVitals.config.enabled
          next if (collector = RailsVitals::Collector.current).nil?

          collector.finalize!(event)
        end
      end

      # Skip Rails internal queries — schema lookups, explain, etc.
      private_class_method def self.internal_query?(sql)
        sql =~ /\A\s*(SCHEMA|EXPLAIN|PRAGMA|BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i ||
        sql.include?("pg_class") ||
        sql.include?("pg_attribute") ||
        sql.include?("pg_type") ||
        sql.include?("t.typname") ||
        sql.include?("t.oid") ||
        sql.include?("information_schema") ||
        sql.include?("pg_namespace") ||
        sql.include?("SHOW search_path")
      end

      private_class_method def self.extract_source(binds)
        # binds is an array of ActiveRecord::Relation::QueryAttribute
        # We just use it as a hook point for now — real caller detection comes later
        nil
      end
    end
  end
end
