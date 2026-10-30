# frozen_string_literal: true

RSpec.describe Deliverance::CLI do
  subject(:cli) { described_class.new(input_reader: reader, logger: logger, output: output) }

  let(:reader) { class_double(Readline) }
  let(:logger) { instance_double(Logger, info: true, error: true) }
  let(:output) { StringIO.new }

  describe '.start' do
    it 'instantiates and runs the CLI' do
      instance = instance_double(described_class, run: nil)
      allow(described_class).to receive(:new).and_return(instance)

      described_class.start

      expect(instance).to have_received(:run)
    end
  end

  describe '#run' do
    it 'terminates when input is nil (Ctrl+D)' do
      allow(reader).to receive(:readline).with('deli:001> ', true).and_return(nil)

      expect { cli.run }.not_to raise_error
    end

    it 'terminates when input is quit or exit (case-insensitive)' do
      allow(reader).to receive(:readline).and_return('QUIT')

      expect { cli.run }.not_to raise_error
      expect(reader).to have_received(:readline).once
    end

    it 'executes commands entered by the user' do
      allow(reader).to receive(:readline).and_return('help', 'exit')

      cli.run

      expect(output.string).to include('Available commands:')
    end

    it 'outputs unknown command message when command is not found' do
      allow(reader).to receive(:readline).and_return('unknown_cmd', 'exit')

      cli.run

      expect(output.string).to include("Unknown command: 'unknown_cmd'")
    end

    it 'increments line counter on each prompt' do
      allow(reader).to receive(:readline).and_return('', 'hello', 'exit')

      cli.run

      expect(reader).to have_received(:readline).with('deli:001> ', true).ordered
      expect(reader).to have_received(:readline).with('deli:002> ', true).ordered
      expect(reader).to have_received(:readline).with('deli:003> ', true).ordered
    end

    it 'catches Interrupt and logs exit hint without crashing' do
      call_count = 0
      allow(reader).to receive(:readline) do
        call_count += 1
        raise Interrupt if call_count == 1

        'exit'
      end

      cli.run

      expect(logger).to have_received(:info).with("Use 'quit' or Ctrl+D to exit!")
    end
  end
end
