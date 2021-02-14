
# frozen_string_literal: true

require_relative "spec_helper"
require_relative "rmq_control"
require "bunny"
require "cuniculus/config"

RSpec.describe Cuniculus::Config do
  subject(:config) { described_class.new }

  before(:all) do
    rmq_host = ENV["RMQ_HOST"] || "rabbitmq"
    @rmq_opts = { host: rmq_host, port: 5672, user: "guest", pass: "guest", vhost: "/" }
    RMQControl.wait_live(10)
  end

  before do
    config.rabbitmq_opts = @rmq_opts
    RMQControl.delete_exchanges
    RMQControl.delete_queues(["cun_dead"])
  end

  # Make sure to recreate the exchanges so other tests can run
  after do
    subject.declare!
  end

  describe "declare!" do
    before { stub_const("Cuniculus::QueueConfig::DEFAULT_MAX_RETRY", 0) }
    it "creates the cuniculus and cuniculus DLX exchanges" do
      subject.declare!
      expect(RMQControl.get_exchanges).to include("cuniculus", "cuniculus_dlx")
    end

    it "creates the default queue" do
      subject.declare!
      expect(RMQControl.get_queues).to include("cun_default")
    end

    context "when default_queue is set to false" do
      before do
        RMQControl.delete_queues(["cun_default"])
        config.default_queue = false
      end
      it "creates the default queue" do
        subject.declare!
        expect(RMQControl.get_queues).not_to include("cun_default")
      end
    end

    it "declares dead queue and binds to DLX exchange" do
      subject.declare!
      expect(RMQControl.get_bindings(Cuniculus::CUNICULUS_DLX_EXCHANGE)).to include("cun_dead")
    end
  end
end
