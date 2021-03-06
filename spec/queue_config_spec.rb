# frozen_string_literal: true

require_relative "spec_helper"
require_relative "rmq_control"
require "bunny"
require "cuniculus/queue_config"

RSpec.describe Cuniculus::QueueConfig do
  subject { described_class.new(opts) }

  before(:all) do
    rmq_host = ENV["RMQ_HOST"] || "rabbitmq"
    rmq_opts = { host: rmq_host, port: 5672, user: "guest", pass: "guest", vhost: "/" }
    RMQControl.wait_live(10)
    @conn = ::Bunny.new(rmq_opts)
    @conn.start
  end

  before(:each) do
    @channel = @conn.create_channel
    @channel.direct(Cuniculus::CUNICULUS_EXCHANGE, { durable: true })
    @channel.fanout(Cuniculus::CUNICULUS_DLX_EXCHANGE, { durable: true })

    # Make sure to clear both the queue in RMQ and the cached queue in @channel
    @channel.queues.each_value(&:delete)
    RMQControl.delete_queues(["cun_default"])
  end

  after(:each) do
    @channel.queues.each_value(&:delete)
    RMQControl.delete_queues(["cun_default"])
  end

  describe "declare!" do
    let(:opts) { {} }

    before { stub_const("Cuniculus::QueueConfig::DEFAULT_MAX_RETRY", 2) }
    context "with default opts" do
      it "declares base queue and associated retry queues" do
        subject.declare!(@channel)
        expect(@channel.queues.keys).to eq(%w[cun_default cun_default_1 cun_default_2])
      end
    end

    context "when a queue already exists with conflicting configs" do
      before do
        channel = @conn.create_channel # separate channel to avoid the cached queue in @channel
        channel.queue("cun_default", durable: false)
      end
      it "raises a RMQQueueConfigurationConflict error" do
        expect { subject.declare!(@channel) }.to raise_exception(Cuniculus::RMQQueueConfigurationConflict)
      end
    end

    context "with non-default options" do
      let(:opts) do
        { name: "test_queue", durable: false, max_retry: 1, prefetch_count: 99, thread_pool_size: 7 }
      end
      it "declares base queue and associated retry queues" do
        subject.declare!(@channel)
        expect(@channel.queues.keys).to eq(%w[test_queue test_queue_1])
        expect(@channel.queues.values.map(&:durable?)).not_to include(true)
      end
    end
  end
end
