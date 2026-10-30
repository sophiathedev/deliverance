# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Deliverance::Commands::Scan do
  let(:output) { StringIO.new }
  let(:logger) { instance_double(Logger, info: true, warn: true) }
  let(:command) { described_class.new(output: output, logger: logger) }

  describe '#execute' do
    it 'prints usage and warns when path is nil or blank' do
      result = command.execute(nil)

      expect(result).to be_nil
      expect(output.string).to include('Usage: scan <path>')
      expect(logger).to have_received(:warn).with('Scan aborted: no path provided')
    end

    it 'scans a directory containing UTF-8 characters and spaces' do
      Dir.mktmpdir do |dir|
        utf8_dir = File.join(dir, 'Thư Mục Dữ Liệu')
        Dir.mkdir(utf8_dir)
        File.write(File.join(utf8_dir, 'tệp_1.txt'), 'nội dung 1')
        sub_dir = File.join(utf8_dir, 'Thư Mục Con')
        Dir.mkdir(sub_dir)
        File.write(File.join(sub_dir, 'tệp_2.md'), '# Markdown')

        result = command.execute(utf8_dir)

        expect(result[:total_objects]).to eq(3)
        expect(result[:files].size).to eq(2)
        expect(result[:directories].size).to eq(1)
      end
    end

    it 'logs progress and renders summary for scanned directory' do
      Dir.mktmpdir do |dir|
        utf8_dir = File.join(dir, 'Thư Mục Test')
        Dir.mkdir(utf8_dir)
        File.write(File.join(utf8_dir, 'tệp_1.txt'), 'test')

        command.execute(utf8_dir)

        expect(logger).to have_received(:info).with("Starting scan for: #{utf8_dir}")
        expect(logger).to have_received(:info).with(/Scan completed: 1 objects found/)
        expect(output.string).to include('Total objects: 1')
      end
    end

    it 'supports glob patterns with *' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'test1.txt'), 'abc')
        File.write(File.join(dir, 'test2.txt'), 'def')
        File.write(File.join(dir, 'script.rb'), 'puts 1')

        glob_pattern = File.join(dir, '*.txt')
        result = command.execute(glob_pattern)

        expect(result[:total_objects]).to eq(2)
        expect(result[:files].size).to eq(2)
        expect(result[:files].all? { |f| f.end_with?('.txt') }).to be true
      end
    end

    it 'supports scanning a single file' do
      Dir.mktmpdir do |dir|
        file_path = File.join(dir, 'single.txt')
        File.write(file_path, 'hello world')

        result = command.execute(file_path)

        expect(result[:total_objects]).to eq(1)
        expect(result[:files]).to eq([file_path])
        expect(result[:directories]).to be_empty
      end
    end

    it 'supports unquoted paths with spaces passed via extra arguments' do
      Dir.mktmpdir do |dir|
        spaced_dir = File.join(dir, 'my test folder')
        Dir.mkdir(spaced_dir)
        File.write(File.join(spaced_dir, 'sample.txt'), 'data')

        parts = spaced_dir.split
        result = command.execute(parts[0], *parts[1..])

        expect(result[:total_objects]).to eq(1)
        expect(result[:files].size).to eq(1)
      end
    end

    it 'handles nonexistent paths gracefully' do
      result = command.execute('/path/to/nonexistent_directory_12345')

      expect(result[:total_objects]).to eq(0)
      expect(result[:files]).to be_empty
      expect(result[:directories]).to be_empty
      expect(output.string).to include('Total objects: 0')
    end

    it 'can be invoked from another command using run_command' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'sample.txt'), 'data')

        caller_cmd = Class.new(Deliverance::Commands::Base) do
          command_name 'caller_test'

          def execute(target_path)
            run_command(:scan, target_path)
          end
        end

        result = caller_cmd.call(dir, context: { output: output, logger: logger })

        expect(result[:total_objects]).to eq(1)
      end
    end
  end
end
