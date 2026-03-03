module RailsVitals
  class Configuration
    attr_accessor :enabled,
                  :store_size,
                  :store_enabled,
                  :auth,
                  :basic_auth_username,
                  :basic_auth_password,
                  :query_warn_threshold,
                  :query_critical_threshold,
                  :db_time_warn_ms,
                  :db_time_critical_ms

    def initialize
      @enabled                  = defined?(Rails) && !Rails.env.production?
      @store_size               = 200
      @store_enabled            = true
      @auth                     = :none
      @basic_auth_username      = nil
      @basic_auth_password      = nil
      @query_warn_threshold     = 10
      @query_critical_threshold = 25
      @db_time_warn_ms          = 100
      @db_time_critical_ms      = 500
    end
  end
end
