# frozen_string_literal: true

RSpec.describe Deliverance::Commands do
  after { Deliverance::Commands.reset_registry! } # rubocop:disable RSpec/DescribedClass

  describe '.find' do
    it 'finds registered commands by name or alias case-insensitively' do
      expect(described_class.find('help')).to eq(Deliverance::Commands::Help)
      expect(described_class.find('HELP')).to eq(Deliverance::Commands::Help)
      expect(described_class.find('h')).to eq(Deliverance::Commands::Help)
      expect(described_class.find('quit')).to eq(Deliverance::Commands::Exit)
    end

    it 'returns nil for unregistered commands' do
      expect(described_class.find('nonexistent')).to be_nil
    end
  end

  describe '.execute' do
    it 'instantiates and executes the command' do
      output = StringIO.new
      described_class.execute('help', context: { output: output })

      expect(output.string).to include('Available commands:')
    end

    it 'raises CommandNotFoundError when command does not exist' do
      expect do
        described_class.execute('unknown_cmd')
      end.to raise_error(Deliverance::Errors::CommandNotFoundError, "Unknown command: 'unknown_cmd'")
    end
  end

  describe Deliverance::Commands::Base do
    it 'raises NotImplementedError when execute is not overridden' do
      base = described_class.new
      expect { base.execute }.to raise_error(NotImplementedError)
    end

    it 'allows commands to invoke other commands via run_command' do
      test_cmd = Class.new(described_class) do
        command_name 'parent_cmd'

        def execute
          run_command(:help)
        end
      end

      output = StringIO.new
      test_cmd.call(context: { output: output })

      expect(output.string).to include('Available commands:')
    end
  end

  describe Deliverance::Commands::Help do
    let(:output) { StringIO.new }
    let(:help_cmd) { described_class.new(output: output) }

    it 'lists all registered commands with their usage and description' do
      help_cmd.execute

      expect(output.string).to include('Available commands:')
      expect(output.string).to include('help [command]')
      expect(output.string).to include('exit')
    end

    it 'shows details for a specific command' do
      help_cmd.execute('help')

      expect(output.string).to include('Command:     help')
      expect(output.string).to include('Usage:       help [command]')
      expect(output.string).to include('Aliases:     h, ?')
    end

    it 'outputs a message when the target command is not found' do
      help_cmd.execute('missing')

      expect(output.string).to include("Command 'missing' not found.")
    end
  end

  describe Deliverance::Commands::Exit do
    it 'throws :exit_repl' do
      expect { described_class.call }.to throw_symbol(:exit_repl)
    end
  end
end
