# frozen_string_literal: true

require "spec_helper"
require_relative "./timeout_queue"
require "cuniculus"
require "cuniculus/pub_worker"

RSpec.describe Cuniculus::PubWorker do
  before(:all) do
    rmq_host = ENV["RMQ_HOST"] || "rabbitmq"
    @rmq_opts = { host: rmq_host, port: 5672, user: "guest", pass: "guest", vhost: "/" }
  end

  let(:config) do
    cfg = Cuniculus::Config.new
    cfg.pub_reconnect_attempts = 10
    cfg.pub_reconnect_delay = 1
    cfg.pub_reconnect_delay_max = 10
    cfg.pub_shutdown_grace_period = 20
    cfg.pub_pool_size = 1
    cfg.rabbitmq_opts = { host: "fake_host", port: 5672, user: "guest", pass: "guest", vhost: "/" }

    cfg
  end
  let(:job_queue) { TimeoutQueue.new(4) }
  let(:dispatcher_chan) { [] }

  subject { described_class.new(config, job_queue, dispatcher_chan) }

  # Make sure background thread is terminates before continuing with other tests
  after do
    job_queue << :shutdown
    t0 = Cuniculus.mark_time
    while subject.alive? && (Cuniculus.mark_time - t0 < 5)
      job_queue << :shutdown
      sleep 0.2
    end
  end

  let(:connection) do
    ::Bunny.new(config.rabbitmq_opts)
  end

  describe "#start!" do
    context "when connection is not open" do
      it "sends a timestamp to the dispatcher channel and does not start background thread" do
        subject.start!(connection)
        sleep 1
        expect(dispatcher_chan.last).to be_within(5).of(Cuniculus.mark_time)
        expect(subject).not_to be_alive
      end
    end

    context "when connection is open" do
      let(:exchange_class) do
        Class.new do
          attr_reader :payloads, :opts
          def initialize
            @payloads = []
            @opts = []
          end

          def publish(payload, opts)
            raise ::Bunny::Exception if payload == :boom
            @payloads << payload
            @opts << opts
          end
        end
      end

      let(:exchange) { exchange_class.new }
      let(:dl_exchange) { exchange_class.new }

      let(:channel) do
        instance_double(
          "Bunny::Channel",
          confirm_select: nil,
          wait_for_confirms: nil,
          closed?: false,
          close: nil,
          direct: exchange,
          fanout: dl_exchange
        )
      end
      let(:connection) do
        instance_double("Bunny::Session", open?: true, create_channel: channel)
      end

      before { subject.start!(connection) }

      it "starts a background thread" do
        expect(subject).to be_alive
      end

      it "shuts down upon receiving a shutdown message" do
        job_queue << :shutdown
        sleep 0.1
        expect(subject).not_to be_alive
      end

      context "when the job does not references the dead-letter exchange" do
        it "publishes payloads it receives in the job queue to the normal exchange" do
          job_queue << [Cuniculus::CUNICULUS_EXCHANGE, "some_payload", "rkey"]
          sleep 0.1
          expect(exchange.payloads).to include("some_payload")
          expect(exchange.opts).to include(routing_key: "rkey", persistent: true)
        end
      end

      context "when the job references the dead-letter exchange" do
        it "publishes payloads it receives in the job queue to the normal exchange" do
          job_queue << [Cuniculus::CUNICULUS_DLX_EXCHANGE, "some_payload", "rkey"]
          sleep 0.1
          expect(dl_exchange.payloads).to include("some_payload")
          expect(dl_exchange.opts).to include(routing_key: "rkey", persistent: true)
        end
      end

      context "when the message publication raises an exception" do
        before do
          job_queue << ["x", :boom, "rkey"]
          sleep 0.1
        end

        it "puts the job back in the job queue" do
          expect(job_queue.pop).to eq(["x", :boom, "rkey"])
        end

        it "shuts down the background thread" do
          expect(subject).not_to be_alive
        end

        it "sends a timestamp into the dispatcher channel" do
          expect(dispatcher_chan.last).to be_within(5).of(Cuniculus.mark_time)
        end
      end
    end
  end
end
