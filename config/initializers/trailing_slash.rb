module Solitr
  module Rack
    class TrailingSlash
      def initialize(app)
        @app = app
      end

      def call(env)
        if env['REQUEST_PATH'].start_with?('/blog') && \
            !env['REQUEST_PATH'].end_with?('/') && \
            File.directory?("public/#{env['REQUEST_PATH']}")
          response = ::Rack::Response.new
          response.redirect "#{env['REQUEST_PATH']}/", 301
          response.finish
        else
          @app.call(env)
        end
      end
    end
  end
end
