# frozen_string_literal: true

RSpec.describe Deliverance::Commands::Cve::Renderer do
  describe '.highlight' do
    it 'returns empty string for nil or empty input' do
      expect(described_class.highlight(nil, 'test')).to eq('')
      expect(described_class.highlight('', 'test')).to eq('')
    end

    it 'returns original text when keyword is blank' do
      expect(described_class.highlight('hello world', '')).to eq('hello world')
      expect(described_class.highlight('hello world', '   ')).to eq('hello world')
    end

    it 'highlights matching words with foreground red' do
      res = described_class.highlight('Apache Log4j exploit in log4j', 'log4j')
      expect(res).to eq("Apache \e[1;31mLog4j\e[0m exploit in \e[1;31mlog4j\e[0m")
    end

    it 'reverts to base color after highlight when base_color is specified' do
      cyan = "\e[1;36m"
      res = described_class.highlight('CVE-2021-44228', '44228', base_color: cyan)
      expect(res).to eq("CVE-2021-\e[1;31m44228\e[0m\e[1;36m")
    end

    it 'handles special regex characters safely' do
      res = described_class.highlight('Version 1.0 (beta) found', '(beta)')
      expect(res).to include("\e[1;31m(beta)\e[0m")
    end
  end

  describe '.severity_badge' do
    it 'returns colored badge with score' do
      badge = described_class.severity_badge('CRITICAL', 9.8)
      expect(badge).to eq("\e[1;97;41m CRITICAL (Score: 9.8) \e[0m")
    end

    it 'returns badge without score when score is nil or N/A' do
      badge = described_class.severity_badge('HIGH', nil)
      expect(badge).to eq("\e[1;97;45m HIGH \e[0m")
    end

    it 'falls back to unknown styling for unrecognized severities' do
      badge = described_class.severity_badge('CUSTOM', 5.0)
      expect(badge).to eq("\e[1;97;100m CUSTOM (Score: 5.0) \e[0m")
    end
  end

  describe '.format_state' do
    it 'formats PUBLISHED in green' do
      expect(described_class.format_state('PUBLISHED')).to eq("\e[1;32mPUBLISHED\e[0m")
    end

    it 'formats REJECTED in red' do
      expect(described_class.format_state('REJECTED')).to eq("\e[1;31mREJECTED\e[0m")
    end

    it 'formats other states in yellow' do
      expect(described_class.format_state('RESERVED')).to eq("\e[1;33mRESERVED\e[0m")
    end
  end
end
