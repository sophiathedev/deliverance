# frozen_string_literal: true

require_relative 'deliverance/version'

require 'readline'
require 'tty-logger'
require 'shellwords'

module Deliverance
  class << self
    attr_writer :logger

    def logger
      @logger ||= TTY::Logger.new do |config|
        config.metadata = %i[date time]
      end
    end
  end

  class CLI
    def self.start
      new.run
    end

    def initialize
      @line_cnt = 0
    end

    def run
      repl_loop
    end

    private

    def repl_loop
      loop do
        @line_cnt += 1
        input = Readline.readline("deli:#{@line_cnt.to_s.rjust(3, '0')}> ", true)&.strip
        break if input.nil? # when using ctrl+d it will return nil

        next if input.empty?
      rescue Interrupt
        Deliverance.logger.info("Use 'quit' or Ctrl+D to exit!\n")
      end
    end
  end
end
