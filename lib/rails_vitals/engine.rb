module RailsVitals
  class Engine < ::Rails::Engine
    isolate_namespace RailsVitals

    initializer "rails_vitals.middleware" do |app|
      if RailsVitals.config.enabled
        app.middleware.use RailsVitals::Middleware::PanelInjector
      end
    end
  end
end
