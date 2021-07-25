# frozen_string_literal: true

require "spec_helper"
require "cuniculus/worker"

RSpec.describe Cuniculus::Worker do
  let(:worker) do
    Class.new do
      extend Cuniculus::Worker
    end
  end
  describe "cuniculus_options" do
    subject { worker.cuniculus_options(opts) }

    context "when cuniculus_options is not called" do
      it "uses default values" do
        expect(worker.cun_opts).to include(
          queue: "cun_default"
        )
      end
    end

    context "when the wrong argument type is passed" do
      let(:opts) { "a string" }
      it { expect { subject }.to raise_exception(Cuniculus::WorkerOptionsError) }
    end

    context "when invalid keys are passed" do
      let(:opts) do
        { invalid_key: 123, "another_invalid_key" => 3, queue: "q" }
      end
      it { expect { subject }.to raise_exception(Cuniculus::WorkerOptionsError) }
    end

    context "when there is a subclass of the original worker class" do
      let(:child_worker) do
        Class.new(worker)
      end
      before do
        worker.cuniculus_options({ queue: "q1" })
      end

      it "inherits the options from the parent worker" do
        expect(child_worker.cun_opts[:queue]).to eq("q1")
      end

      context "when child worker overrides the options" do
        before { child_worker.cuniculus_options({ queue: "q2" }) }
        it { expect(child_worker.cun_opts[:queue]).to eq("q2") }

        it "does not change the parent worker options" do
          expect(worker.cun_opts[:queue]).to eq("q1")
        end
      end
    end
  end

end
