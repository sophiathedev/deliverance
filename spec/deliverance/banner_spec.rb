# frozen_string_literal: true

RSpec.describe Deliverance::Banner do
  describe '.styles' do
    it 'returns the list of available banner styles' do
      expect(described_class.styles).to include(
        :bubble, :chunky, :doom, :graffiti, :slant, :small, :speed, :standard
      )
    end
  end

  describe '.banner_for' do
    it 'returns the raw banner text for a valid style' do
      text = described_class.banner_for(:slant)
      expect(text).to be_a(String)
      expect(text).to include('/ (_)   _____')
    end

    it 'returns nil for an unknown style' do
      expect(described_class.banner_for(:non_existent)).to be_nil
    end
  end

  describe '.random_style' do
    it 'returns a symbol belonging to styles' do
      expect(described_class.styles).to include(described_class.random_style)
    end
  end

  describe '.render' do
    it 'renders plain text when color is false' do
      output = described_class.render(:slant, color: false)
      expect(output).not_to include("\e[")
      expect(output).to include('/ (_)   _____')
    end

    it 'renders ANSI colored text when color is true' do
      output = described_class.render(:slant, color: true)
      expect(output).to start_with("\e[1;36m")
      expect(output).to end_with("\e[0m")
    end

    it 'includes the version and a quote in the rendered banner' do
      output = described_class.render(:slant, color: false)
      expect(output).to include("v#{Deliverance::VERSION}")
      expect(output).to match(/~ ".+"/)
    end

    it 'returns empty string for invalid style' do
      expect(described_class.render(:invalid_style)).to eq('')
    end

    it 'picks a style randomly when style is nil' do
      output = described_class.render(nil, color: false)
      expect(output).not_to be_empty
    end

    it 'renders lowercase banner content across all styles' do
      described_class.styles.each do |style|
        content = described_class.render(style, color: false)
        expect(content).not_to be_empty
      end
    end
  end

  describe '.random' do
    it 'renders a colored banner string' do
      output = described_class.random
      expect(output).to include("\e[0m")
    end
  end
end
