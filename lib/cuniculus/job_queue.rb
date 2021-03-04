# frozen_string_literal: true

require "forwardable"
module Cuniculus
  class JobQueue
    extend Forwardable

    def_delegators :@base_queue, :message_count, :subscribe

    def initialize(base_queue, retry_queue_names)
      @base_queue = base_queue
      @retry_queue_names = retry_queue_names
    end

    def retry_queue(retry_count)
      @retry_queue_names[retry_count]
    end
  end
end
