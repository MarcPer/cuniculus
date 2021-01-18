# frozen_string_literal: true

require "cuniculus/worker"

class MyWorker
  include Cuniculus::Worker

  def perform(arg1, arg2)
    puts "Processing:"
    puts "arg1: #{arg1.inspect}"
    puts "arg2: #{arg2.inspect}"
    sleep 1
  end
end
