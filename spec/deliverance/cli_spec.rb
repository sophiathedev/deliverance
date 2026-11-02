# frozen_string_literal: true

require 'tempfile'

RSpec.describe Deliverance::CLI do
  subject(:cli) do
    described_class.new(
      input_reader: reader,
      logger: logger,
      output: output,
      history_file: nil
    )
  end

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
    it 'prints a deliverance banner on startup' do
      allow(reader).to receive(:readline).and_return('exit')

      cli.run

      expect(output.string).to include("\e[0m\n\n")
    end

    it 'omits banner when banner option is false' do
      no_banner_cli = described_class.new(
        input_reader: reader,
        logger: logger,
        output: output,
        history_file: nil,
        banner: false
      )
      allow(reader).to receive(:readline).and_return('exit')

      no_banner_cli.run

      expect(output.string).to be_empty
    end

    it 'terminates when input is nil (Ctrl+D)' do
      allow(reader).to receive(:readline).with('deli:001> ', false).and_return(nil)

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

      expect(output.string).to include("Available commands:\n")
      expect(output.string).to end_with("\n")
    end

    it 'executes clear command' do
      allow(reader).to receive(:readline).and_return('clear', 'exit')

      cli.run

      expect(output.string).to include("\e[H\e[2J\e[3J")
    end

    it 'outputs unknown command message when command is not found' do
      allow(reader).to receive(:readline).and_return('unknown_cmd', 'exit')

      cli.run

      expect(output.string).to include("Unknown command: 'unknown_cmd'")
    end

    it 'increments line counter on each prompt' do
      allow(reader).to receive(:readline).and_return('', 'hello', 'exit')

      cli.run

      expect(reader).to have_received(:readline).with('deli:001> ', false).ordered
      expect(reader).to have_received(:readline).with('deli:002> ', false).ordered
      expect(reader).to have_received(:readline).with('deli:003> ', false).ordered
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

  describe 'command history management' do
    let(:history_file) { Tempfile.new('deli_history') }
    let(:history_cli) do
      described_class.new(
        input_reader: Readline,
        logger: logger,
        output: output,
        history_file: history_file.path
      )
    end

    after do
      history_file.close
      history_file.unlink
    end

    it 'records commands and persists them to history file' do
      allow(Readline).to receive(:readline).and_return('help', 'clear', 'exit')

      history_cli.run

      saved = File.read(history_file.path)
      expect(saved).to include("help\nclear\nexit")
    end

    it 'loads previous commands from history file on start' do
      history_file.write("status\nscan lib\n")
      history_file.flush

      allow(Readline).to receive(:readline).and_return('exit')

      history_cli.run

      expect(Readline::HISTORY.to_a).to include('status', 'scan lib')
    end
  end
end
