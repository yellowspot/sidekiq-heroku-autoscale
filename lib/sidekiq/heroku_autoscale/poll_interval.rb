require 'concurrent'

module Sidekiq
  module HerokuAutoscale

    class PollInterval
      attr_reader :requests, :pool

      def initialize(method_name, before_update: 0, after_update: 0)
        @method_name = method_name
        @before_update = before_update
        @after_update = after_update
        @requests = Concurrent::Hash.new
        @semaphore = Mutex.new
        @pool = Concurrent::ThreadPoolExecutor.new(
          min_threads: 0,
          max_threads: 1,
          max_queue: 1,
          fallback_policy: :discard
        )
      end

      def call(process)
        return unless process
        @semaphore.synchronize do
          @requests[process.name] ||= process
        end
        poll!
      end

      def poll!
        @pool.post do
          while @requests.size > 0
            # Copy the requests, let the main thread continue to add new requests
            @work = nil
            @semaphore.synchronize do
              @work = @requests.dup
              @work.each { |name, _process| @requests.delete(name) }
            end

            while @work.size > 0
              sleep(@before_update) if @before_update > 0
              @work.reject! { |n, p| p.send(@method_name) }
              sleep(@after_update) if @after_update > 0
            end
          end
        end
      end
    end
  end
end
