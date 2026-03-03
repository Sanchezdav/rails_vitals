require "rails_vitals/version"
require "rails_vitals/configuration"
require "rails_vitals/panel_renderer"
require "rails_vitals/middleware/panel_injector"
require "rails_vitals/engine"

module RailsVitals
  class << self
    def configure
      yield config
    end

    def config
      @config ||= Configuration.new
    end
  end
end
