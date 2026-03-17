require "rails_vitals/version"
require "rails_vitals/configuration"
require "rails_vitals/store"
require "rails_vitals/collector"
require "rails_vitals/request_record"
require "rails_vitals/notifications/subscriber"
require "rails_vitals/instrumentation/callback_instrumentation"
require "rails_vitals/analyzers/n_plus_one_aggregator"
require "rails_vitals/analyzers/sql_tokenizer"
require "rails_vitals/analyzers/association_mapper"
require "rails_vitals/analyzers/explain_analyzer"
require "rails_vitals/scorers/base_scorer"
require "rails_vitals/scorers/query_scorer"
require "rails_vitals/scorers/n_plus_one_scorer"
require "rails_vitals/scorers/composite_scorer"
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

    def store
      @store ||= Store.new(config.store_size)
    end
  end
end
