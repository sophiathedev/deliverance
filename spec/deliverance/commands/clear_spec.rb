# frozen_string_literal: true

RSpec.describe Deliverance::Commands::Clear do
  let(:output) { StringIO.new }
  let(:command) { described_class.new(output: output) }

  describe '#execute' do
    it 'prints the ANSI clear terminal escape code' do
      command.execute

      expect(output.string).to eq("\e[H\e[2J\e[3J")
    end

    it 'is registered with alias cls' do
      expect(described_class.aliases).to include('cls')
    end
  end
end
