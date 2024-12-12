module Sidekiq
  module HerokuAutoscale

    class PollInterval
      def initialize(method_name, before_update: 0, after_update: 0)
        @method_name = method_name
        @before_update = before_update
        @after_update = after_update
        @requests = {}
        @semaphore = Mutex.new
      end

      def call(process)
        ::Sidekiq.logger.info("PollInterval (#{!!::Sidekiq.server?}): #{process&.name}")
        return unless process
        ::Sidekiq.logger.info("PollInterval (#{!!::Sidekiq.server?}) - Storing process #{@requests.keys}")
        @semaphore.synchronize do
          ::Sidekiq.logger.info("PollInterval (#{!!::Sidekiq.server?}) - Lock gain")
          @requests[process.name] ||= process
        end
        ::Sidekiq.logger.info("PollInterval (#{!!::Sidekiq.server?}) - Now polling")
        poll!
      end

      def poll!
        @thread ||= Thread.new do
          begin
            ::Sidekiq.logger.info("PollInterval (#{!!::Sidekiq.server?}) - Thread started #{@requests.size}")
            while @requests.size > 0
              ::Sidekiq.logger.info("PollInterval (#{!!::Sidekiq.server?}) - About to sleep for #{@before_update}")
              sleep(@before_update) if @before_update > 0
              ::Sidekiq.logger.info("PollInterval (#{!!::Sidekiq.server?}) - Wakeup before_update #{@before_update}")
              @semaphore.synchronize do
                ::Sidekiq.logger.info("PollInterval (#{!!::Sidekiq.server?}) - Rejecting all updated #{@requests.size} using #{@method_name}")
                @requests.reject! { |n, p| p.send(@method_name) }
                ::Sidekiq.logger.info("PollInterval (#{!!::Sidekiq.server?}) - After rejecting size #{@requests.size}")
              end
              ::Sidekiq.logger.info("PollInterval (#{!!::Sidekiq.server?}) - About to sleep again #{@after_update}")
              sleep(@after_update) if @after_update > 0

              ::Sidekiq.logger.info("PollInterval (#{!!::Sidekiq.server?}) - After iteration size #{@requests.size}")
            end
          ensure
            ::Sidekiq.logger.info("PollInterval (#{!!::Sidekiq.server?}) - Cleaning thread")
            @thread = nil
          end
        end
      end
    end

  end
end
