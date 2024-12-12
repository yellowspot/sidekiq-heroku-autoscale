module Sidekiq
  module HerokuAutoscale

    class PollInterval
      attr_reader :thread

      def initialize(method_name, before_update: 0, after_update: 0)
        @method_name = method_name
        @before_update = before_update
        @after_update = after_update
        @requests = {}
        @semaphore = Mutex.new
        @thread = 1
      end

      def call(process)
        log("Call Init: #{process&.name}")
        return unless process
        log("Storing process #{@requests.keys}")
        @semaphore.synchronize do
          log("Lock gain")
          @requests[process.name] ||= process
        end
        log("Now polling")
        poll!
      end

      def poll!
        log("Does thread exists? #{@thread != 1}")
        @thread = Thread.new do
          begin
            log("Thread started #{@requests.size}")
            while @requests.size > 0
              log("About to sleep for #{@before_update}")
              sleep(@before_update) if @before_update > 0
              log("Wakeup before_update #{@before_update}")
              @semaphore.synchronize do
                log("Rejecting all updated #{@requests.size} using #{@method_name}")
                @requests.reject! { |n, p| p.send(@method_name) }
                log("After rejecting size #{@requests.size}")
              end
              log("About to sleep again #{@after_update}")
              sleep(@after_update) if @after_update > 0

              log("After iteration size #{@requests.size}")
            end
          ensure
            @semaphore.synchronize do
              log("Cleaning thread")
              @thread = 1
            end
          end
        end if @thread == 1
      end


      def log(message)
        type = !!::Sidekiq.server? ? 'server' : 'client'
        ::Sidekiq.logger.info("PollInterval (#{type} - #{@method_name}): #{message}")
      end
    end
  end
end
