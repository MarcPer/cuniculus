
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
    RMQControl.delete_queues(%w[q1 q1_1 cun_dead])
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

  describe "add_queue" do
    context "when passed options don't contain a 'name' key" do
      let(:queue_opts) { { random_key: " " } }
      it { expect { subject.add_queue(queue_opts) }.to raise_exception(Cuniculus::ConfigError) }
    end

    context "when passed options don't contain a valid 'name' key" do
      let(:queue_opts) { { name: " " } }
      it { expect { subject.add_queue(queue_opts) }.to raise_exception(Cuniculus::ConfigError) }
    end

    context "when options are valid" do
      let(:queue_opts) do
        {
          name: "q1", durable: false, max_retry: 1, prefetch_count: 50
        }
      end
      it "stores QueueConfig object with correct parameters" do
        subject.add_queue(queue_opts)
        q = subject.queues["q1"]
        expect(q.name).to eq("q1")
        expect(q.durable).to eq(false)
        expect(q.max_retry).to eq(1)
        expect(q.prefetch_count).to eq(50)
      end
    end
  end
end
