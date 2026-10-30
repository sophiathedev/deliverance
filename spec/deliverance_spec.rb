# frozen_string_literal: true

RSpec.describe Deliverance do
  it 'has a version number' do
    expect(Deliverance::VERSION).not_to be_nil
  end

  it 'defines a standard error class' do
    expect(Deliverance::Error.new).to be_a(StandardError)
  end

  describe '.logger' do
    after { described_class.logger = nil }

    it 'formats message with timestamp and 5-character aligned level' do
      output = StringIO.new
      logger = Logger.new(output, formatter: described_class.logger.formatter)

      logger.info('info msg')
      logger.debug('debug msg')

      lines = output.string.lines
      expect(lines[0]).to match(/\A\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[INFO \] info msg\n\z/)
      expect(lines[1]).to match(/\A\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[DEBUG\] debug msg\n\z/)
    end

    it 'defaults to debug level in development' do
      expect(described_class.logger.level).to eq(Logger::DEBUG)
    end

    it 'defaults to info level when not in development' do
      allow(described_class).to receive(:development?).and_return(false)
      described_class.logger = nil
      expect(described_class.logger.level).to eq(Logger::INFO)
    end
  end
end
