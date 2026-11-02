# frozen_string_literal: true

require 'logger'

require_relative 'deliverance/version'
require_relative 'deliverance/errors'
require_relative 'deliverance/banner'
require_relative 'deliverance/commands'
require_relative 'deliverance/cli'

module Deliverance
  Error = Errors::Error
  CommandNotFoundError = Errors::CommandNotFoundError

  LOG_TIMESTAMP_FORMAT = '%Y-%m-%d %H:%M:%S'
  LOG_SEVERITY_WIDTH = 5

  class << self
    attr_writer :logger

    def env
      ENV['DELIVERANCE_ENV'] ||
        ENV['APP_ENV'] ||
        (File.exist?(File.expand_path('../Gemfile', __dir__)) ? 'development' : 'production')
    end

    def development?
      env == 'development'
    end

    def logger
      @logger ||= Logger.new(
        $stdout,
        level: development? ? Logger::DEBUG : Logger::INFO,
        formatter: default_formatter
      )
    end

    private

    def default_formatter
      proc do |severity, datetime, _progname, msg|
        timestamp = datetime.strftime(LOG_TIMESTAMP_FORMAT)
        level = severity.to_s.ljust(LOG_SEVERITY_WIDTH)
        "[#{timestamp}] [#{level}] #{msg.to_s.chomp}\n"
      end
    end
  end
end
