require "test_helper"

class RailsVitalsCallbackInstrumentationTest < ActiveSupport::TestCase
  test "#run_callbacks returns recorded callback hash with keys :model :kind :duration_ms when kind is tracked" do
    klass = Class.new do
      def run_callbacks(_kind, *_args)
        :base_result
      end
    end
    klass.prepend(RailsVitals::Instrumentation::CallbackInstrumentation)

    collector = RailsVitals::Collector.new
    RailsVitals::Collector.current = collector

    with_rails_vitals_config(enabled: true) do
      result = klass.new.run_callbacks(:save)
      assert_equal :base_result, result
    end

    assert_equal 1, collector.callbacks.size
    callback = collector.callbacks.first
    assert_nil callback[:model]
    assert_equal :save, callback[:kind]
    assert_kind_of Numeric, callback[:duration_ms]
  ensure
    RailsVitals::Collector.reset!
  end

  test "#run_callbacks returns super result and does not add callback when kind is not tracked" do
    klass = Class.new do
      def run_callbacks(_kind, *_args)
        :base_result
      end
    end
    klass.prepend(RailsVitals::Instrumentation::CallbackInstrumentation)

    collector = RailsVitals::Collector.new
    RailsVitals::Collector.current = collector

    with_rails_vitals_config(enabled: true) do
      result = klass.new.run_callbacks(:touch)
      assert_equal :base_result, result
    end

    assert_equal [], collector.callbacks
  ensure
    RailsVitals::Collector.reset!
  end

  test "#run_callbacks returns super result and does not add callback when collector is missing" do
    klass = Class.new do
      def run_callbacks(_kind, *_args)
        :base_result
      end
    end
    klass.prepend(RailsVitals::Instrumentation::CallbackInstrumentation)

    RailsVitals::Collector.reset!

    with_rails_vitals_config(enabled: true) do
      result = klass.new.run_callbacks(:save)
      assert_equal :base_result, result
    end
  end
end
