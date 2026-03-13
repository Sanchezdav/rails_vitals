require "test_helper"

class RailsVitalsTest < ActiveSupport::TestCase
  test ".VERSION is present" do
    assert RailsVitals::VERSION
  end

  test ".configure returns assigned config values after yielding mutable Configuration object" do
    original_store_size = RailsVitals.config.store_size
    original_store_enabled = RailsVitals.config.store_enabled

    RailsVitals.configure do |config|
      config.store_size = 321
      config.store_enabled = false
    end

    assert_equal 321, RailsVitals.config.store_size
    refute RailsVitals.config.store_enabled
  ensure
    RailsVitals.configure do |config|
      config.store_size = original_store_size
      config.store_enabled = original_store_enabled
    end
  end

  test ".store returns RailsVitals::Store whose capacity comes from config.store_size at initialization time" do
    original_store_size = RailsVitals.config.store_size
    original_store = RailsVitals.instance_variable_get(:@store)

    RailsVitals.configure { |config| config.store_size = 7 }
    RailsVitals.instance_variable_set(:@store, nil)

    assert_equal 7, RailsVitals.store.instance_variable_get(:@size)
  ensure
    RailsVitals.configure { |config| config.store_size = original_store_size }
    RailsVitals.instance_variable_set(:@store, original_store)
  end
end
