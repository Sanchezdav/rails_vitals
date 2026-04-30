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
          ActiveSupport::SecurityUtils.secure_compare(username, RailsVitals.config.basic_auth_username.to_s) &
            ActiveSupport::SecurityUtils.secure_compare(password, RailsVitals.config.basic_auth_password.to_s)
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
