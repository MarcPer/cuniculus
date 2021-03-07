# frozen_string_literal: true

require "spec_helper"
require_relative "stub_supervisor"
require "cuniculus/config"
require "cuniculus/plugins"
require "cuniculus/plugins/health_check"

require "net/http"
require "socket"

RSpec.describe Cuniculus::Plugins::HealthCheck do
  let(:port) { 5544 }

  before(:all) do
    config = Cuniculus::Config.new
    k = Class.new(Cuniculus::StubSupervisor) do
      include Cuniculus::Plugins::HealthCheck::SupervisorMethods
    end

    opts = { "bind_to" => "0.0.0.0", "port" => 5544, "path" => "alive", "quiet" => true }
    described_class.configure(config.opts, opts)
    @supervisor = k.new(config)

    @original_stderr = $stderr.clone
    @original_stdout = $stdout.clone

    # Supress output from WEBrick
    $stdout.reopen(File.new("/dev/null", "w"))
    $stderr.reopen(File.new("/dev/null", "w"))

    @supervisor.start
    # Wait until server is up
    20.times do
      Socket.tcp("127.0.0.1", 5544, connect_timeout: 2) { |s| nil }
      break
    rescue Errno::ECONNREFUSED
      sleep 0.1
    end
  end

  after(:all) do
    @supervisor.stop
    sleep 0.5
    $stdout.reopen(@original_stdout)
    $stderr.reopen(@original_stderr)
  end

  describe "start" do
    context "when a request is sent to the configured port, but different path" do
      it "returns 404 Not Found" do
        res = Net::HTTP.get_response("localhost", "/healthcheck", port)
        expect(res.code).to eq("404")
      end
    end

    context "when a request is sent to the configured port, but different path" do
      it "returns 404 Not Found" do
        res = Net::HTTP.get_response("localhost", "/alive", port)
        expect(res.code).to eq("200")
      end
    end
  end
end
