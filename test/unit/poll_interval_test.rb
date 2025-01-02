# frozen_string_literal: true

require 'test_helper'

describe 'Sidekiq::HerokuAutoscale::PollInterval' do
  describe 'call' do
    it 'does nothing when process is nil' do
      poll_interval = ::Sidekiq::HerokuAutoscale::PollInterval.new(:reject?)

      poll_interval.call(nil)
      assert_empty poll_interval.requests
      # It does not start the polling thread
      assert_equal 0, poll_interval.pool.length
    end

    # Ensure that "RuntimeError: can't add a new key into hash during iteration" isn't raised
    # when multiple threads are trying to modify the `requests` hash.
    it 'properly manages concurrent access to requests' do
      poll_interval = ::Sidekiq::HerokuAutoscale::PollInterval.new(:reject?)

      poll_interval.call(TestPollIntervalProcess.new(name: :a, rejectable: false))

      thread = Thread.new do
        2_000.times do |i|
          poll_interval.call(TestPollIntervalProcess.new(name: i, rejectable: i.odd?))
        end
      end

      1_000.times do |i|
        poll_interval.call(TestPollIntervalProcess.new(name: i + 300, rejectable: i.odd?))
      end

      # `sleep 5` is the optimal delay to make the error reproducible in 100% of cases
      sleep 5
      poll_interval.instance_variable_set(:@requests, {})

      thread.join
      poll_interval.pool.shutdown
      poll_interval.pool.wait_for_termination(1)
    end
  end
end
