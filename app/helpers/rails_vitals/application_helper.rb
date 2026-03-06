module RailsVitals
  module ApplicationHelper
    def score_color(color)
      case color
      when "green" then "#276749"
      when "blue"  then "#2b6cb0"
      when "amber" then "#b7791f"
      else              "#c53030"
      end
    end
  end
end
