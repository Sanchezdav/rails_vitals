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

    def score_label_to_color(score)
      case score
      when 90..100 then "healthy"
      when 70..89  then "acceptable"
      when 50..69  then "warning"
      else              "critical"
      end
    end

    def callback_color(kind)
      case kind.to_sym
      when :validation, :save   then "#2b6cb0"
      when :create, :update     then "#276749"
      when :destroy             then "#c53030"
      when :commit              then "#b7791f"
      when :rollback            then "#742a2a"
      else                           "#4a5568"
      end
    end
  end
end
