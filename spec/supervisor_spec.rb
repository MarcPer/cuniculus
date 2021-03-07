# frozen_string_literal: true

require_relative "spec_helper"
require_relative "rmq_control"
require "cuniculus/supervisor"
require "cuniculus/config"
require "cuniculus/queue_config"

RSpec.describe Cuniculus::Supervisor do
  let(:supervisor) { described_class.new(config) }

  let(:conn_opts) do
    rmq_host = ENV["RMQ_HOST"] || "rabbitmq"
    { host: rmq_host, port: 5672, user: "guest", pass: "guest", vhost: "/" }
  end

  let(:config) do
    Cuniculus::Config.new.tap do |cfg|
      cfg.rabbitmq_opts = conn_opts
    end
  end

  before(:all) do
    RMQControl.wait_live(10)
  end

  describe "create_consumers" do
    subject { supervisor.create_consumers(connection, queues) }
    let(:connection) { supervisor.connect(conn_opts) }
    let(:queues) do
      {
        "q1" => Cuniculus::QueueConfig.new({ "name" => "q1", "max_retry" => 0, "durable" => false, "prefetch_count" => 66 }),
        "q2" => Cuniculus::QueueConfig.new({ "name" => "q2", "max_retry" => 0, "durable" => false, "prefetch_count" => 77 })
      }
    end

    it "creates channels with configured prefetch counts" do
      q1 = subject.find { |c| c.queue_config.name == "q1" }
      q2 = subject.find { |c| c.queue_config.name == "q2" }
      expect(q1.channel.prefetch_count).to eq(66)
      expect(q2.channel.prefetch_count).to eq(77)
    end
  end
end
