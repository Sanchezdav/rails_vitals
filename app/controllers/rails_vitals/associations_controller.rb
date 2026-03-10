module RailsVitals
  class AssociationsController < ApplicationController
    def index
      @nodes, @canvas_height = Analyzers::AssociationMapper.build(RailsVitals.store)
      @node_map = @nodes.index_by(&:name)
    end
  end
end
