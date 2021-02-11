# frozen_string_literal: true

$stdout.sync = true

require "optparse"
require "singleton"

require "cuniculus"
require "cuniculus/supervisor"

module Cuniculus
  class CLI
    include Singleton

    attr_reader :options

    def parse(args = ARGV)
      @options = parse_options(args)

      return unless options[:require]

      raise ArgumentError, "Invalid '--require' argument: #{options[:require]}. File does not exist" unless File.exist?(options[:require])
      raise ArgumentError, "Invalid '--require' argument: #{options[:require]}. Cannot be a directory" if File.directory?(options[:require])
      require File.join(Dir.pwd, options[:require])
    end

    def run
      pipe_reader, pipe_writer = IO.pipe
      sigs = %w[INT TERM]

      sigs.each do |sig|
        trap sig do
          pipe_writer.puts(sig)
        end
      rescue ArgumentError
        puts "Signal #{sig} not supported"
      end


      launch(pipe_reader)
    end

    def launch(pipe_reader)
      config = Cuniculus.config
      supervisor = Cuniculus::Supervisor.new(config)

      begin
        Cuniculus.logger.info("Starting process")
        supervisor.start

        while (readable_io = IO.select([pipe_reader]))
          signal = readable_io.first[0].gets.strip
          handle_signal(signal)
        end
      rescue Interrupt
        Cuniculus.logger.info("Interrupt received; shutting down")
        supervisor.stop
        Cuniculus.logger.info("Shutdown complete")
      end

      exit(0)
    end

    def handle_signal(sig)
      case sig
      when "INT", "TERM"
        raise Interrupt
      end
    end

    private

    def parse_options(argv)
      opts = {}
      @parser = option_parser(opts)
      @parser.parse!(argv)
      opts
    end

    def option_parser(opts)
      OptionParser.new do |o|
        o.on("-r", "--require [PATH]", "location of file required before starting consumer") do |arg|
          opts[:require] = arg
        end

        o.on("-I", "--include [DIR]", "add directory to LOAD_PATH") do |arg|
          $LOAD_PATH << arg
        end

        o.on "-V", "--version", "print version and exit" do |arg|
          puts "Cuniculus #{Cuniculus.version}"
          exit(0)
        end
      end
    end
  end
end

