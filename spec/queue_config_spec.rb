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
    @conn = ::Bunny.new(rmq_opts)
    @conn.start
    @channel = @conn.create_channel
  end

  before do
    # Make sure to clear both the queue in RMQ and the cached queue in @channel
    @channel.queues.each_value(&:delete)
    RMQControl.delete_queues(%w[default default_1 default_2])
  end

  after do
    @channel.queues.each_value(&:delete)
    RMQControl.delete_queues(%w[default default_1 default_2])
  end

  describe "declare!" do
    let(:opts) { {} }

    before { stub_const("Cuniculus::QueueConfig::DEFAULT_MAX_RETRY", 2) }
    context "with default opts" do

      it "declares base queue and associated retry queues" do
        subject.declare!(@channel)
        expect(@channel.queues.keys).to eq(%w[default default_1 default_2])
      end
    end

    context "when a queue already exists with conflicting configs" do
      before do
        @channel.queue("default", durable: false)
      end
      it "raises a RMQQueueConfigurationConflict error" do
        channel = @conn.create_channel # separate channel to avoid the cached queue in @channel
        expect { subject.declare!(channel) }.to raise_error(Cuniculus::RMQQueueConfigurationConflict)
      end
    end
  end
end
