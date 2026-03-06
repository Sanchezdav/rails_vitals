module RailsVitals
  class ApplicationController < ActionController::Base
    before_action :authenticate!
    before_action :flag_own_request

    private

    def authenticate!
      auth = RailsVitals.config.auth

      case auth
      when :none
        true
      when :basic
        authenticate_or_request_with_http_basic("RailsVitals") do |username, password|
          username == RailsVitals.config.basic_auth_username &&
            password == RailsVitals.config.basic_auth_password
        end
      when Proc
        unless auth.call(self)
          render plain: "Unauthorized", status: :unauthorized
        end
      end
    end

    def flag_own_request
      Thread.current[:rails_vitals_own_request] = true
    end
  end
end
