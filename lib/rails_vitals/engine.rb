module RailsVitals
  class Engine < ::Rails::Engine
    isolate_namespace RailsVitals

    initializer "rails_vitals.middleware" do |app|
      if RailsVitals.config.enabled
        app.middleware.use RailsVitals::Middleware::PanelInjector
      end
    end

    initializer "rails_vitals.notifications" do
      if RailsVitals.config.enabled
        RailsVitals::Notifications::Subscriber.attach
      end
    end

    initializer "rails_vitals.mcp" do
      if RailsVitals.config.mcp_enabled
        raise "RailsVitals MCP cannot run in production" if Rails.env.production?

        require "rails_vitals/mcp/auth"
        require "rails_vitals/mcp/response_builder"
        require "rails_vitals/mcp/tool_registry"
        require "rails_vitals/mcp/tools/base"
        require "rails_vitals/mcp/request_handler"
        require "rails_vitals/mcp/tools/get_score"
        require "rails_vitals/mcp/tools/get_n1_queries"
      end
    end

    config.to_prepare do
      if RailsVitals.config.enabled
        ActiveRecord::Base.prepend(
          RailsVitals::Instrumentation::CallbackInstrumentation
        )
      end
    end
  end
end
