
# frozen_string_literal: true

require "stringio"
require_relative "spec_helper"
require_relative "rmq_control"
require "cuniculus"
require "cuniculus/logger"
require "cuniculus/dispatcher"

RSpec.describe Cuniculus::Dispatcher do
  let(:channel) { instance_double("Bunny::Channel", ack: nil, nack: nil) }
  let(:queue) { instance_double("Bunny::Queue", subscribe: nil) }
  let(:queue_config) { instance_double("Cuniculus::QueueConfig", declare!: nil) }
  let(:exchange) { instance_double("Bunny::Exchange", publish: nil) }

  before(:all) do
    rmq_host = ENV["RMQ_HOST"] || "rabbitmq"
    @rmq_opts = { host: rmq_host, port: 5672, user: "guest", pass: "guest", vhost: "/" }
  end

  before do
    @logio = StringIO.new
    Cuniculus.instance_variable_set(:@logger, Cuniculus::Logger.new(@logio, level: Logger::INFO))
  end

  let(:pool_size) { 3 }
  let(:config) do
    cfg = Cuniculus::Config.new
    cfg.pub_reconnect_attempts = 10
    cfg.pub_reconnect_delay = 1
    cfg.pub_reconnect_delay_max = 10
    cfg.pub_shutdown_grace_period = 20
    cfg.pub_pool_size = pool_size
    cfg.rabbitmq_opts = @rmq_opts
    cfg
  end

  subject { described_class.new(config) }


  describe ".initialize" do
    it { expect(subject.instance_variable_get(:@workers).size).to eq(pool_size) }
  end

  describe "#start!" do
    before(:all) do
      RMQControl.wait_live(10)
    end

    let(:connection) { subject.instance_variable_get(:@conn) }


    it "opens connection to RabbitMQ" do
      subject.start!

      5.times do
        break if connection.open?
        sleep 0.5
      end

      expect(connection).to be_open
    end

    it "shuts down upon receiving a :shutdown message in its channel" do
      subject.start!
      5.times do
        break if subject.alive?
        sleep 0.5
      end

      subject.dispatcher_chan << :shutdown
      5.times do
        break unless subject.alive?
        sleep 0.5
      end

      expect(subject).not_to be_alive
    end

    describe "connection recovery" do
      context "when it receives a timestamp in its channel" do
        before do
          subject.start!
          5.times do
            break if connection.open?
            sleep 0.5
          end

          connection.close
          5.times do
            break if connection.closed?
            sleep 0.5
          end
          raise "Failed to disconnect" unless connection.closed?
        end

        context "but the timestamp is from before the last connection" do
          before do
            subject.dispatcher_chan << Cuniculus.mark_time - 10000

            # Even though the connection should not restart, we give it time
            # to make sure it really didn't start, avoiding the case where
            # the spec passes only because the check was done too fast.
            5.times do
              break if connection.open?
              sleep 0.5
            end
          end

          it "does not reconnect" do
            expect(connection).not_to be_open
          end
        end

        context "and the timestamp is from after the last connection" do
          before do
            subject.dispatcher_chan << Cuniculus.mark_time + 10000
            5.times do
              break if connection.open?
              sleep 0.5
            end
          end

          it "reconnects" do
            expect(connection).to be_open
          end
        end
      end
    end

    describe "worker threads" do
      let(:workers) { subject.instance_variable_get(:@workers) }

      context "when it receives a timestamp in its channel" do
        before do
          subject.start!
          5.times do
            break if workers.all?(&:alive?)
            sleep 0.5
          end
          raise "Failed to start workers" unless workers.all?(&:alive?)

          # Force workers shutdown so we can test their restart
          workers.size.times { subject.job_queue << :shutdown }

          5.times do
            break if workers.none?(&:alive?)
            sleep 0.5
          end
          raise "Failed to stop workers" unless workers.none?(&:alive?)
        end

        context "but the timestamp is from before the last connection" do
          before do
            subject.dispatcher_chan << Cuniculus.mark_time - 10000

            # Even though workers should not restart, we give them time
            # to make sure they really didn't start, avoiding the case where
            # the spec passes only because the check was done too fast.
            5.times do
              break if workers.any?(&:alive?)
              sleep 0.5
            end
          end

          it "does not restart workers" do
            workers.each { |w| expect(w).not_to be_alive }
          end
        end

        context "and the timestamp is from after the last connection" do
          before do
            subject.dispatcher_chan << Cuniculus.mark_time + 10000
            5.times do
              break if workers.any?(&:alive?)
              sleep 0.5
            end
          end

          it "restarts workers" do
            expect(workers).to all(be_alive)
          end
        end
      end
    end
  end
end

