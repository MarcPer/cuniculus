# frozen_string_literal: true

# A queue implementation with a pop method that times out
class TimeoutQueue
  def initialize(timeout)
    raise ArgumentError, "Requires a positive integer timeout argument" unless timeout.to_i > 0
    @timeout = timeout
    @queue = []
    @mutex = Mutex.new
    @cv = ConditionVariable.new
  end

  def <<(x)
    @mutex.synchronize do
      @queue << x
      @cv.signal
    end
  end

  def pop
    start = Cuniculus.mark_time
    @mutex.synchronize do
      while @queue.empty? && (remaining_time = Cuniculus.mark_time - start) < @timeout
        @cv.wait(@mutex, remaining_time)
      end
      raise ThreadError if @queue.empty?
      @queue.pop
    end
  end
end

