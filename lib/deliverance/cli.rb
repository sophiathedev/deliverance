# frozen_string_literal: true

require 'readline'
require 'shellwords'

module Deliverance
  class CLI
    PROMPT_FORMAT = 'deli:%03d> '
    EXIT_HINT = "Use 'quit' or Ctrl+D to exit!"
    DEFAULT_HISTORY_FILE = File.expand_path('~/.deliverance_history')
    MAX_HISTORY_ENTRIES = 1000

    def self.start
      new.run
    end

    def initialize(
      input_reader: Readline,
      logger: Deliverance.logger,
      output: $stdout,
      history_file: DEFAULT_HISTORY_FILE
    )
      @input_reader = input_reader
      @logger = logger
      @output = output
      @history_file = history_file
      @line_cnt = 0
    end

    def run
      load_history
      catch :exit_repl do
        repl_loop
      end
    ensure
      save_history_to_file
    end

    private

    attr_reader :input_reader, :logger, :output, :history_file

    def repl_loop
      loop do
        @line_cnt += 1
        prompt = format(PROMPT_FORMAT, @line_cnt)
        input = input_reader.readline(prompt, false)&.strip

        break if input.nil?
        next if input.empty?

        record_history(input)
        dispatch(input)
        output.puts
      rescue Interrupt
        logger.info(EXIT_HINT)
      end
    end

    def record_history(input)
      return if input.nil? || input.empty?
      return unless defined?(Readline::HISTORY) && input_reader == Readline
      return if Readline::HISTORY.to_a.last == input

      Readline::HISTORY.push(input)
    end

    def load_history
      return unless history_file && File.exist?(history_file)
      return unless defined?(Readline::HISTORY) && input_reader == Readline

      File.foreach(history_file, chomp: true) do |line|
        record_history(line)
      end
    rescue SystemCallError
      # ignore unreadable history file
    end

    def save_history_to_file
      return unless history_file && defined?(Readline::HISTORY) && input_reader == Readline

      entries = Readline::HISTORY.to_a.last(MAX_HISTORY_ENTRIES)
      File.write(history_file, "#{entries.join("\n")}\n")
    rescue SystemCallError
      # ignore unwritable history file
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
