module RailsVitals
  module Instrumentation
    module CallbackInstrumentation
      TRACKED_CALLBACKS = %i[
        validation save create update destroy commit rollback
      ].freeze

      def run_callbacks(kind, *args, &block)
        collector = RailsVitals::Collector.current

        unless collector && RailsVitals.config.enabled &&
               TRACKED_CALLBACKS.include?(kind)
          return super
        end

        start  = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
        result = super
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond) - start

        collector.add_callback(
          model:       self.class.name,
          kind:        kind,
          duration_ms: duration.round(2)
        )

        result
      end
    end
  end
end
