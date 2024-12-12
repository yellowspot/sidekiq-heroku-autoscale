module Sidekiq
  module HerokuAutoscale

    class Middleware
      def initialize(app)
        @app = app
      end

      def call(worker_class, item, queue, _=nil)
        result = yield

        Sidekiq.logger.info "Middleware (#{!!::Sidekiq.server?}): #{worker_class} #{item} #{queue}"
        if process = @app.process_for_queue(queue)
          Sidekiq.logger.info "Middleware (#{!!::Sidekiq.server?}): ping #{process.name}"
          process.ping!
        end

        Sidekiq.logger.info "Middleware (#{!!::Sidekiq.server?}): process? #{!process.nil?}"

        result
      end
    end

  end
end
