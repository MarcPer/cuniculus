# frozen_string_literal: true

require "cuniculus/worker"

module Examples
  class MyWorker
    include Cuniculus::Worker
    cuniculus_options queue: "my_queue"

    def perform(arg1)
      puts "Processing: #{arg1.inspect}"
      sleep 1
    end
  end
end
