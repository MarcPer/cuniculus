# frozen_string_literal: true

require "logger"
require "time"

module Cuniculus
  class Logger < ::Logger
    def initialize(*args, **kwargs)
      super
      self.formatter = Formatters::Standard.new
    end

    module Formatters
      class Base
        def tid
          Thread.current["cuniculus_tid"] ||= (Thread.current.object_id ^ ::Process.pid).to_s(36)
        end
      end

      class Standard < Base
        def call(severity, time, _program_name, message)
          "#{time.utc.iso8601(3)} pid=#{::Process.pid} tid=#{tid} #{severity}: #{message}\n"
        end
      end
    end
  end
end
