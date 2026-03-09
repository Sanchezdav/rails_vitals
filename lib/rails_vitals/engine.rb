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

    config.to_prepare do
      if RailsVitals.config.enabled
        ActiveRecord::Base.prepend(
          RailsVitals::Instrumentation::CallbackInstrumentation
        )
      end
    end
  end
end
