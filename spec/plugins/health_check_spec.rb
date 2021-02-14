# frozen_string_literal: true

require "spec_helper"
require_relative "stub_supervisor"
require "cuniculus/config"
require "cuniculus/plugins"
require "cuniculus/plugins/health_check"

require "net/http"

RSpec.describe Cuniculus::Plugins::HealthCheck do
  let(:plugged) do
    config = Cuniculus::Config.new
    k = Class.new(Cuniculus::StubSupervisor) do
      include Cuniculus::Plugins::HealthCheck::SupervisorMethods
    end

    opts = { "bind_to" => "0.0.0.0", "port" => 0 }
    described_class.configure(config.opts, opts)
    k.new(config)
  end

  let(:plugin_opts) do
    plugged.config.opts["__health_check_opts"]
  end

  after do
    plugged.stop
  end

  describe "start" do
    it "starts a TCP server that returns 200 OK" do
      plugged.start
      port = plugin_opts["port"]
      res = Net::HTTP.get_response("localhost", "/", port)
      expect(res.code).to eq("200")
    end
  end
end
