module Solitr
  module Rack
    class Headers
      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, body = @app.call(env)

        duration = nil
        if Rails.env.production?
          case env['REQUEST_PATH']
          when %r{^/assets/.*-[0-9a-f]{32,}}
            duration = 1.month
          else
            duration = 1.hour
          end
        end

        if duration
          headers['Expires'] = "#{duration.from_now}"
          headers['Cache-Control'] = "public, max-age=#{duration.to_i}"
        else
          headers['Pragma'] = 'no-cache'
          headers['Cache-Control'] = 'no-cache'
          headers['Expires'] = '-1'
          # Sometimes ETag and Last-Modified headers are messed up by Sprockets
          if Rails.env.development?
            headers.delete 'ETag'
            headers.delete 'Last-Modified'
          end
        end

        [status, headers, body]
      end
    end
  end
end
