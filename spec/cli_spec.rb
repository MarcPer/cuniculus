# frozen_string_literal: true

require_relative "spec_helper"
require "cuniculus/cli"

RSpec.describe Cuniculus::CLI do
  subject { described_class.instance }

  describe "#parse" do
    context "when -r PATH is passed" do
      context "but there is no file in PATH" do
        args = %w[cuniculus -r missing_file.rb]
        it { expect { subject.parse(args) }.to raise_exception(ArgumentError) }
      end

      context "but there PATH points to a directory" do
        args = %w[cuniculus -r .]
        it { expect { subject.parse(args) }.to raise_exception(ArgumentError) }
      end
    end
  end

  describe "#handle_signal" do
    %w[INT TERM].each do |sig|
      context "when #{sig} is received" do
        it { expect { subject.handle_signal(sig) }.to raise_exception(Interrupt) }
      end
    end
  end
end
