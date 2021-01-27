# frozen_string_literal: true

require "stringio"
require "warning"
require_relative "spec_helper"
require "bunny"
require "cuniculus"
require "cuniculus/consumer"
require "cuniculus/queue_config"
require "cuniculus/logger"
require "cuniculus/worker"

Warning.ignore(:method_redefined)
RSpec.describe Cuniculus::Consumer do
  let(:channel) { instance_double("Bunny::Channel", ack: nil, nack: nil) }
  let(:queue) { instance_double("Bunny::Queue", subscribe: nil) }
  let(:queue_config) { instance_double("Cuniculus::QueueConfig", declare!: nil) }
  let(:exchange) { instance_double("Bunny::Exchange", publish: nil) }
  let(:worker) do
    Class.new do
      @stored_arg = nil
      class << self
        attr_accessor :stored_arg
      end
      include Cuniculus::Worker
      def perform(arg)
        self.class.stored_arg = arg
      end
    end
  end


  let(:consumer) { described_class.new(queue_config, channel) }
  before do
    @logio = StringIO.new
    Cuniculus.instance_variable_set(:@logger, Cuniculus::Logger.new(@logio, level: Logger::INFO))
    consumer.instance_variable_set(:@exchange, exchange)
    job_queue = Cuniculus::JobQueue.new(queue, %w[retry_1 retry_2])
    consumer.instance_variable_set(:@job_queue, job_queue)
    stub_const("TestWorker", worker)
  end

  describe "#run_job" do
    let(:delivery_info) { instance_double("Bunny::DeliveryInfo", delivery_tag: 57) }
    subject { consumer.run_job(delivery_info, nil, payload) }


    context "when payload is not in JSON format" do
      let(:payload) { "just a string" }
      it "rejects message without requeuing" do
        expect(channel).to receive(:nack).with(57, false, false)
        subject
      end
    end

    context "when payload is missing the 'class' key" do
      let(:payload) do
        Cuniculus.dump_job({ "args"=> [1, 2] })
      end
      it "rejects message without requeuing" do
        expect(channel).to receive(:nack).with(57, false, false)
        subject
      end
    end

    context "when an exception is raised by the worker" do
      let(:worker) do
        Class.new do
          include Cuniculus::Worker
          def perform(arg1, arg2)
            raise ArgumentError, "damaged worker"
          end
        end
      end

      context "and job hasn't been retried yet" do
        let(:payload) do
          Cuniculus.dump_job({ "class" => "TestWorker", "args"=> [1, 2] })
        end
        it "requeues message to 'retry_1' queue" do
          expect(exchange).to receive(:publish).with(
            Cuniculus.dump_job({ "class" => "TestWorker", "args" => [1, 2], "_cun_retries" => 1 }),
            { routing_key: "retry_1", persistent: true }
          )
          subject
        end

        it "acknowledges the original message" do
          expect(channel).to receive(:ack).with(57, false)
          subject
        end
      end

      context "and there are no retries left for the job" do
        let(:payload) do
          Cuniculus.dump_job({ "class" => "TestWorker", "args"=> [1, 2], "_cun_retries" => 2 })
        end
        it "rejects message without requeuing" do
          expect(channel).to receive(:nack).with(57, false, false)
          subject
        end
      end

      context "when error handler hasn't been overriden" do
        let(:payload) do
          Cuniculus.dump_job({ "class" => "TestWorker", "args"=> [1, 2] })
        end

        it "logs exception to Cuniculus logger" do
          subject
          expect(@logio.string).to include("ArgumentError: damaged worker")
        end
      end

      context "when error handler has been overriden" do
        before do
          consumer.instance_variable_set(:@other_logger, StringIO.new)
          Cuniculus::Consumer.instance_eval do
            alias_method :orig_handle_error, :handle_error
          end
          Cuniculus.error_handler do |e|
            @other_logger.puts(e.message)
          end
        end

        # Remove method override
        after do
          meth = consumer.method(:orig_handle_error)
          Cuniculus.error_handler(&meth)
          Cuniculus::Consumer.instance_eval do
            undef_method(:orig_handle_error)
          end
        end
        let(:payload) do
          Cuniculus.dump_job({ "class" => "TestWorker", "args"=> [1, 2] })
        end

        it "runs block defined by error_handler" do
          subject
          logger = consumer.instance_variable_get(:@other_logger)
          expect(logger.string).to include("ArgumentError: damaged worker")
        end
      end
    end
  end
end

