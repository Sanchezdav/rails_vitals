module RailsVitals
  module Middleware
    class PanelInjector
      def initialize(app)
        @app = app
      end

      def call(env)
        RailsVitals::Collector.current = RailsVitals::Collector.new

        status, headers, response = @app.call(env)

        return [ status, headers, response ] unless injectable?(headers, env)

        body = extract_body(response)
        body = inject_panel(body)

        headers["Content-Length"] = body.bytesize.to_s

        [ status, headers, [ body ] ]
      ensure
        RailsVitals::Collector.reset!
      end

      private

      def injectable?(headers, env)
        html_response?(headers) &&
          !xhr_request?(env) &&
          !turbo_frame_request?(env)
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

      def extract_body(response)
        body = ""
        response.each { |chunk| body << chunk }
        body
      end

      def inject_panel(body)
        return body unless body.include?("</body>")

        collector = RailsVitals::Collector.current
        return body if collector.nil?

        panel_html = RailsVitals::PanelRenderer.render(collector)
        body.sub("</body>", "#{panel_html}</body>")
      end
    end
  end
end
