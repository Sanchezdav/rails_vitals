module RailsVitals
  module Middleware
    class PanelInjector
      def initialize(app)
        @app = app
      end

      def call(env)
        Thread.current[:rails_vitals_path] = env["PATH_INFO"]
        RailsVitals::Collector.current = RailsVitals::Collector.new

        status, headers, response = @app.call(env)

        return [status, headers, response] unless injectable?(headers, env)

        collector = RailsVitals::Collector.current
        scorer = Scorers::CompositeScorer.new(collector)
        record = RequestRecord.new(collector: collector, scorer: scorer)

        RailsVitals.store.push(record) if RailsVitals.config.store_enabled

        body = extract_body(response)
        body = inject_panel(body, collector, scorer)

        headers["Content-Length"] = body.bytesize.to_s

        [status, headers, [body]]
      ensure
        Thread.current[:rails_vitals_own_request] = nil
        RailsVitals::Collector.reset!
      end

      private

      def injectable?(headers, env)
        html_response?(headers) &&
          !xhr_request?(env) &&
          !turbo_frame_request?(env) &&
          !rails_vitals_request?(env)
      end

      def html_response?(headers)
        content_type = headers["Content-Type"] || ""
        content_type.include?("text/html")
      end

      def xhr_request?(env)
        env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
      end

      def turbo_frame_request?(env)
        env["HTTP_TURBO_FRAME"].present?
      end

      def rails_vitals_request?(env)
        env["SCRIPT_NAME"].to_s.start_with?("/rails_vitals")
      end

      def extract_body(response)
        body = ""
        response.each { |chunk| body << chunk }
        body
      end

      def inject_panel(body, collector, scorer)
        return body unless body.include?("</body>")

        Rails.logger.debug "RailsVitals PATH_INFO: #{Thread.current[:rails_vitals_path]}"

        panel_html = RailsVitals::PanelRenderer.render(collector, scorer)
        body.sub("</body>", "#{panel_html}</body>")
      end
    end
  end
end
