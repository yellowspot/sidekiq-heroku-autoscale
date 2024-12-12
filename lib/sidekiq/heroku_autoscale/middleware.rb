module Sidekiq
  module HerokuAutoscale

    class Middleware
      def initialize(app)
        @app = app
      end

      def call(worker_class, item, queue, _=nil)
        result = yield

        log("#{worker_class} #{queue}", !!_)
        if process = @app.process_for_queue(queue)
          log("ping to #{process.name}", !!_)
          process.ping!
        end

        result
      end

      def log(message, client_middleware = true)
        type = !!::Sidekiq.server? ? 'server' : 'client'
        middleware_type = client_middleware ? 'client' : 'server'
        ::Sidekiq.logger.info("Middleware (#{type} - #{middleware_type}): #{message}")
      end
    end

  end
end
