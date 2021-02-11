# frozen_string_literal: true

module Cuniculus
  module SupervisorMethods
    attr_reader :config

    def initialize(config)
      @config = config
    end
    def start; end
    def stop; end
  end
  class StubSupervisor
    include SupervisorMethods
  end
end
