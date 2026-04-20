require "test_helper"

class RailsVitalsConfigurationTest < ActiveSupport::TestCase
  test "#initialize returns configuration object with default typed values for thresholds and toggles" do
    config = RailsVitals::Configuration.new

    assert_includes [ true, false ], config.enabled
    assert_equal 200, config.store_size
    assert_equal true, config.store_enabled
    assert_equal :none, config.auth
    assert_nil config.basic_auth_username
    assert_nil config.basic_auth_password
    assert_equal 10, config.query_warn_threshold
    assert_equal 25, config.query_critical_threshold
    assert_equal 100, config.db_time_warn_ms
    assert_equal 500, config.db_time_critical_ms
    assert_equal false, config.mcp_enabled
    assert_nil config.mcp_auth_token
    assert_equal 100, config.mcp_max_log_size
    assert_equal 100, config.mcp_slow_query_threshold_ms
  end

  test "configuration accessors return assigned values for auth credentials store scoring thresholds and mcp settings" do
    config = RailsVitals::Configuration.new

    config.enabled = true
    config.store_size = 500
    config.store_enabled = false
    config.auth = :basic
    config.basic_auth_username = "dev"
    config.basic_auth_password = "secret"
    config.query_warn_threshold = 8
    config.query_critical_threshold = 21
    config.db_time_warn_ms = 80
    config.db_time_critical_ms = 450
    config.mcp_enabled = true
    config.mcp_auth_token = "mcp-secret"
    config.mcp_max_log_size = 250
    config.mcp_slow_query_threshold_ms = 180

    assert config.enabled
    assert_equal 500, config.store_size
    refute config.store_enabled
    assert_equal :basic, config.auth
    assert_equal "dev", config.basic_auth_username
    assert_equal "secret", config.basic_auth_password
    assert_equal 8, config.query_warn_threshold
    assert_equal 21, config.query_critical_threshold
    assert_equal 80, config.db_time_warn_ms
    assert_equal 450, config.db_time_critical_ms
    assert config.mcp_enabled
    assert_equal "mcp-secret", config.mcp_auth_token
    assert_equal 250, config.mcp_max_log_size
    assert_equal 180, config.mcp_slow_query_threshold_ms
  end
end
