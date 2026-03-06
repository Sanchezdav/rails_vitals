# lib/rails_vitals/panel_renderer.rb
module RailsVitals
  class PanelRenderer
    def self.render(collector, scorer)
      new(collector, scorer).render
    end

    def initialize(collector, scorer)
      @collector = collector
      @scorer    = scorer
    end

    def render
      <<~HTML
        <div id="rails-vitals-panel" style="#{panel_styles}">
          #{toggle_button}
          #{collapsed_badge}
          #{expanded_content}
        </div>
        #{inline_script}
      HTML
    end

    private

    # ─── PANEL WRAPPER ───────────────────────────────────────────

    def panel_styles
      "position:fixed;bottom:20px;right:20px;z-index:999999;font-family:monospace;font-size:12px;"
    end

    # ─── COLLAPSED STATE ─────────────────────────────────────────

    def collapsed_badge
      <<~HTML
        <div id="rv-badge" style="
          background:#{score_bg};
          color:#fff;
          padding:6px 12px;
          border-radius:6px;
          cursor:pointer;
          display:flex;
          align-items:center;
          gap:8px;
          box-shadow:0 2px 8px rgba(0,0,0,0.3);
        " onclick="rvToggle()">
          <span style="font-weight:bold;font-size:14px;">#{@scorer.score}</span>
          <span style="opacity:0.85;">#{@scorer.label}</span>
          <span style="opacity:0.6;font-size:10px;">▲</span>
        </div>
      HTML
    end

    def toggle_button; ""; end

    # ─── EXPANDED STATE ───────────────────────────────────────────

    def expanded_content
      <<~HTML
        <div id="rv-expanded" style="
          display:none;
          background:#1a1a2e;
          color:#e2e8f0;
          border-radius:8px;
          padding:16px;
          margin-bottom:8px;
          width:380px;
          box-shadow:0 4px 20px rgba(0,0,0,0.5);
          border:1px solid #2d3748;
        ">
          #{header_section}
          #{divider}
          #{request_info_section}
          #{divider}
          #{query_summary_section}
          #{divider}
          #{slowest_queries_section}
          #{divider}
          #{admin_link_section}
        </div>
      HTML
    end

    # ─── SECTIONS ────────────────────────────────────────────────

    def header_section
      <<~HTML
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:8px;">
          <div>
            <span style="font-size:28px;font-weight:bold;color:#{score_bg};">#{@scorer.score}</span>
            <span style="font-size:13px;color:#a0aec0;margin-left:6px;">/ 100</span>
          </div>
          <div style="text-align:right;">
            <div style="
              background:#{score_bg};
              color:#fff;
              padding:3px 10px;
              border-radius:4px;
              font-size:11px;
              font-weight:bold;
            ">#{@scorer.label}</div>
          </div>
        </div>
      HTML
    end

    def request_info_section
      <<~HTML
        <div style="margin-bottom:4px;">
          #{label_row("Endpoint", "#{@collector.controller}##{@collector.action}")}
          #{label_row("Method",   @collector.http_method.to_s.upcase)}
          #{label_row("Status",   @collector.response_status.to_s)}
          #{label_row("Duration", "#{@collector.duration_ms&.round(1)}ms")}
        </div>
      HTML
    end

    def query_summary_section
      n_plus_one_count = n_plus_one_scorer.n_plus_one_patterns.size

      <<~HTML
        <div style="margin-bottom:4px;">
          #{label_row("Queries",   @collector.total_query_count.to_s)}
          #{label_row("DB Time",   "#{@collector.total_db_time_ms.round(1)}ms")}
          #{label_row("N+1",       n_plus_one_badge(n_plus_one_count))}
        </div>
      HTML
    end

    def slowest_queries_section
      queries = @collector.slowest_queries(5)
      return "" if queries.empty?

      rows = queries.map do |q|
        sql     = truncate(q[:sql], 45)
        time_ms = q[:duration_ms].round(1)
        <<~HTML
          <div style="margin-bottom:6px;">
            <div style="color:#90cdf4;font-size:11px;">#{escape(sql)}</div>
            <div style="color:#68d391;font-size:10px;">#{time_ms}ms</div>
          </div>
        HTML
      end

      <<~HTML
        <div>
          <div style="color:#a0aec0;font-size:10px;margin-bottom:6px;text-transform:uppercase;letter-spacing:0.05em;">
            Slowest Queries
          </div>
          #{rows.join}
        </div>
      HTML
    end

    def admin_link_section
      record = RailsVitals.store.all.last
      return "" unless record

      <<~HTML
        <div style="text-align:right;margin-top:4px;">
          <a href="/rails_vitals/requests/#{record.id}"
            style="color:#90cdf4;font-size:11px;text-decoration:none;"
            target="_blank">
            View full report →
          </a>
        </div>
      HTML
    end

    # ─── HELPERS ─────────────────────────────────────────────────

    def divider
      "<div style='border-top:1px solid #2d3748;margin:10px 0;'></div>"
    end

    def label_row(label, value)
      <<~HTML
        <div style="display:flex;justify-content:space-between;padding:2px 0;">
          <span style="color:#a0aec0;">#{label}</span>
          <span style="color:#e2e8f0;">#{value}</span>
        </div>
      HTML
    end

    def n_plus_one_badge(count)
      return "<span style='color:#68d391;'>None</span>" if count.zero?

      "<span style='background:#e53e3e;color:#fff;padding:1px 6px;border-radius:3px;font-size:10px;'>#{count} detected</span>"
    end

    def score_bg
      case @scorer.color
      when "green" then "#276749"
      when "blue"  then "#2b6cb0"
      when "amber" then "#b7791f"
      else              "#c53030"
      end
    end

    def n_plus_one_scorer
      @n_plus_one_scorer ||= Scorers::NPlusOneScorer.new(@collector)
    end

    def truncate(str, length)
      str.length > length ? "#{str[0, length]}…" : str
    end

    def escape(str)
      str.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
    end

    # ─── JAVASCRIPT ──────────────────────────────────────────────

    def inline_script
      <<~HTML
        <script>
          function rvToggle() {
            var expanded = document.getElementById('rv-expanded');
            var badge    = document.getElementById('rv-badge');
            var arrow    = badge.querySelector('span:last-child');
            if (expanded.style.display === 'none') {
              expanded.style.display = 'block';
              arrow.textContent = '▼';
            } else {
              expanded.style.display = 'none';
              arrow.textContent = '▲';
            }
          }
        </script>
      HTML
    end
  end
end
