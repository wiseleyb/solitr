module Solitr
  module Rack
    class Headers
      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, body = @app.call(env)

        case env['REQUEST_PATH']
        when %r{^/assets/.*-[0-9a-f]{32,}}
          duration = 1.month
        else
          duration = 1.hour
        end
        headers['Expires'] = "#{duration.from_now}"
        headers['Cache-Control'] = "public, max-age=#{duration.to_i}"

        [status, headers, body]
      end
    end
  end
end
