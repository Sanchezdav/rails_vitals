module RailsVitals
  module ApplicationHelper
    COLOR_GREEN = "#276749"
    COLOR_BLUE = "#2b6cb0"
    COLOR_AMBER = "#b7791f"
    COLOR_RED = "#c53030"
    COLOR_DARK_RED = "#742a2a"
    COLOR_GRAY = "#4a5568"
    COLOR_NEUTRAL = "#a0aec0"
    COLOR_LIGHT_RED = "#fc8181"
    COLOR_ORANGE = "#f6ad55"
    COLOR_LIGHT_GREEN = "#68d391"

    def score_color(color)
      case color
      when "green" then COLOR_GREEN
      when "blue"  then COLOR_BLUE
      when "amber" then COLOR_AMBER
      else              COLOR_RED
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
      when :validation, :save   then COLOR_BLUE
      when :create, :update     then COLOR_GREEN
      when :destroy             then COLOR_RED
      when :commit              then COLOR_AMBER
      when :rollback            then COLOR_DARK_RED
      else                           COLOR_GRAY
      end
    end

    def query_heat_color(count)
      if count >= 25    then COLOR_LIGHT_RED
      elsif count >= 10 then COLOR_ORANGE
      else                   COLOR_LIGHT_GREEN
      end
    end

    def time_heat_color(ms)
      if ms >= 500    then COLOR_LIGHT_RED
      elsif ms >= 100 then COLOR_ORANGE
      else                 COLOR_LIGHT_GREEN
      end
    end

    def n1_heat_color(pct)
      if pct >= 75    then COLOR_LIGHT_RED
      elsif pct >= 25 then COLOR_ORANGE
      else                 COLOR_LIGHT_GREEN
      end
    end

    def cost_color(cost)
      return COLOR_NEUTRAL unless cost
      cost = cost.to_f
      if    cost < 100   then COLOR_LIGHT_GREEN
      elsif cost < 1000  then COLOR_ORANGE
      else                    COLOR_LIGHT_RED
      end
    end

    def time_color(ms)
      return COLOR_NEUTRAL unless ms
      ms = ms.to_f
      if    ms < 10   then COLOR_LIGHT_GREEN
      elsif ms < 100  then COLOR_ORANGE
      else                 COLOR_LIGHT_RED
      end
    end

    def rows_color(rows)
      return COLOR_NEUTRAL unless rows
      rows = rows.to_i
      if    rows < 1_000   then COLOR_LIGHT_GREEN
      elsif rows < 10_000  then COLOR_ORANGE
      else                      COLOR_LIGHT_RED
      end
    end

    # Returns a hex color for a DNA risk level symbol (:healthy, :neutral, :warning, :danger)
    def risk_color(risk)
      {
        healthy: COLOR_LIGHT_GREEN,
        neutral: COLOR_NEUTRAL,
        warning: COLOR_ORANGE,
        danger:  COLOR_LIGHT_RED
      }[risk.to_sym] || COLOR_NEUTRAL
    end

    # Returns a readable hex text color for a numeric health score (0-100)
    def score_text_color(score)
      case score.to_i
      when 90..100 then COLOR_LIGHT_GREEN
      when 70..89  then "#4299e1"
      when 50..69  then COLOR_ORANGE
      else              COLOR_LIGHT_RED
      end
    end
  end
end
