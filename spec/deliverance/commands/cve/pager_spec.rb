# frozen_string_literal: true

RSpec.describe Deliverance::Commands::Cve::Pager do
  let(:output) { StringIO.new }

  describe '.interactive?' do
    it 'returns false if input does not respond to getch' do
      non_getch = Object.new
      expect(described_class.interactive?(non_getch)).to be(false)
    end

    it 'returns false if input has tty? returning false' do
      pipe_input = instance_double(IO, getch: 'q', tty?: false)
      expect(described_class.interactive?(pipe_input)).to be(false)
    end

    it 'returns true if input responds to getch and tty is true' do
      tty_input = instance_double(IO, getch: 'q', tty?: true)
      expect(described_class.interactive?(tty_input)).to be(true)
    end
  end

  describe '.read_key' do
    it 'maps quit keys' do
      expect(described_class.read_key(double(getch: 'q'))).to eq(:quit)
      expect(described_class.read_key(double(getch: 'Q'))).to eq(:quit)
      expect(described_class.read_key(double(getch: "\u0003"))).to eq(:quit)
    end

    it 'maps navigation keys to right and left' do
      expect(described_class.read_key(double(getch: "\e[C"))).to eq(:right)
      expect(described_class.read_key(double(getch: 'n'))).to eq(:right)
      expect(described_class.read_key(double(getch: "\e[D"))).to eq(:left)
      expect(described_class.read_key(double(getch: 'p'))).to eq(:left)
    end

    it 'returns unknown for unrecognized character' do
      expect(described_class.read_key(double(getch: 'z'))).to eq(:unknown)
    end
  end

  describe '.paginate' do
    let(:small_results) { { total: 5, items: [{ id: 'CVE-1', description: 'Test' }] } }
    let(:large_results) do
      {
        total: 25,
        items: Array.new(10) { |i| { id: "CVE-#{i + 1}", description: "Test #{i + 1}" } }
      }
    end

    it 'renders immediately without pager loop when total <= 10' do
      described_class.paginate(small_results, 'test', { output: output })
      expect(output.string).to include('Found 5 CVE(s) matching')
      expect(output.string).not_to include('-- Page')
    end

    it 'renders single page and exits when input is non-interactive' do
      non_interactive = instance_double(IO, tty?: false)
      described_class.paginate(large_results, 'test', { output: output, input: non_interactive })
      expect(output.string).to include('Found 25 CVE(s) matching')
      expect(output.string).not_to include('-- Page')
    end

    it 'runs interactive pager and exits on q' do
      interactive_input = instance_double(IO, tty?: true, getch: 'q')
      described_class.paginate(large_results, 'test', { output: output, input: interactive_input })
      expect(output.string).to include('Page 1 of 3')
      expect(output.string).to include('-- Page 1/3 (25 CVEs)')
    end

    it 'navigates to next page on right key press' do
      keys = ["\e[C", 'q']
      interactive_input = instance_double(IO, tty?: true)
      allow(interactive_input).to receive(:getch) { keys.shift }

      client = class_double(Net::HTTP)
      page2_data = { total: 25, items: [{ id: 'CVE-11', description: 'Page 2 item' }] }
      allow(Deliverance::Commands::Cve::Searcher).to receive(:search).and_return(page2_data)

      described_class.paginate(large_results, 'test', { output: output, input: interactive_input }, client)
      expect(output.string).to include('Page 2 of 3')
      expect(output.string).to include('[11]')
      expect(output.string).to include('CVE-11')
    end
  end
end
