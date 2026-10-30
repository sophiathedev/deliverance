# frozen_string_literal: true

require 'readline'
require 'shellwords'

module Deliverance
  class CLI
    PROMPT_FORMAT = 'deli:%03d> '
    EXIT_HINT = "Use 'quit' or Ctrl+D to exit!"

    def self.start
      new.run
    end

    def initialize(input_reader: Readline, logger: Deliverance.logger, output: $stdout)
      @input_reader = input_reader
      @logger = logger
      @output = output
      @line_cnt = 0
    end

    def run
      catch :exit_repl do
        repl_loop
      end
    end

    private

    attr_reader :input_reader, :logger, :output

    def repl_loop
      loop do
        @line_cnt += 1
        prompt = format(PROMPT_FORMAT, @line_cnt)
        input = input_reader.readline(prompt, true)&.strip

        break if input.nil?
        next if input.empty?

        dispatch(input)
      rescue Interrupt
        logger.info(EXIT_HINT)
      end
    end

    def dispatch(input)
      command_name, *args = parse_input(input)
      return unless command_name

      Commands.execute(command_name, *args, context: command_context)
    rescue Errors::CommandNotFoundError => e
      output.puts e.message
    rescue StandardError => e
      logger.error("Command error: #{e.message}")
    end

    def parse_input(input)
      Shellwords.split(input)
    rescue ArgumentError
      input.split
    end

    def command_context
      {
        cli: self,
        logger: logger,
        output: output
      }
    end
  end
end
