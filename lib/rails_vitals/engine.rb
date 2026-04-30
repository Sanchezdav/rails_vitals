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
        unless RailsVitals.config.permitted_environment?
          raise "RailsVitals MCP cannot run in #{Rails.env} environment. " \
                "Permitted: #{RailsVitals::Configuration::PERMITTED_ENVIRONMENTS.join(', ')}"
        end

        require "rails_vitals/mcp/auth"
        require "rails_vitals/mcp/response_builder"
        require "rails_vitals/mcp/tool_registry"
        require "rails_vitals/mcp/tools/base"
        require "rails_vitals/mcp/request_handler"
        require "rails_vitals/mcp/tools/get_score"
        require "rails_vitals/mcp/tools/get_n1_queries"
        require "rails_vitals/mcp/tools/get_slow_queries"
        require "rails_vitals/mcp/tools/get_request_log"
        require "rails_vitals/mcp/tools/get_schema_context"
        require "rails_vitals/mcp/tools/explain_query"
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
