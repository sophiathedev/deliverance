# frozen_string_literal: true

RSpec.describe Deliverance::Commands::Cve do
  let(:output) { StringIO.new }
  let(:logger) { instance_double(Logger, info: true) }
  let(:http_client) { class_double(Net::HTTP) }
  let(:command) do
    described_class.new(output: output, logger: logger, http_client: http_client)
  end

  def sample_cve_json
    JSON.generate(
      cveMetadata: {
        cveId: 'CVE-2021-44228',
        state: 'PUBLISHED',
        assignerShortName: 'apache',
        datePublished: '2021-12-10T00:00:00.000Z'
      },
      containers: {
        cna: {
          title: 'Log4Shell Vulnerability',
          descriptions: [{ value: 'Remote code execution in Apache Log4j' }],
          metrics: [{ 'cvssV3_1' => { 'baseScore' => 10.0, 'baseSeverity' => 'CRITICAL' } }]
        }
      }
    )
  end

  def sample_ghsa_json
    JSON.generate(
      ghsa_id: 'GHSA-2j8w-xcrc-x985',
      cve_id: nil,
      summary: 'Rack authority bypass',
      description: 'Host header validation bypass in Rack',
      severity: 'medium',
      state: 'published',
      published_at: '2026-10-30T02:18:58Z',
      cvss: { 'score' => 4.8 },
      vulnerabilities: [{ 'package' => { 'name' => 'rack', 'ecosystem' => 'rubygems' } }]
    )
  end

  describe '#execute' do
    it 'shows usage when called without arguments' do
      command.execute

      expect(output.string).to include('Usage: cve info <CVE-ID | GHSA-ID>')
      expect(output.string).to include('Subcommands:')
    end

    it 'shows usage when called with an unknown subcommand' do
      command.execute('unknown')

      expect(output.string).to include('Usage: cve info <CVE-ID | GHSA-ID>')
    end

    describe 'info subcommand' do
      it 'outputs an error for invalid code format' do
        result = command.execute('info', 'invalid_code')

        expect(result).to be_nil
        expect(output.string).to include('Error: Invalid code format')
      end

      it 'fetches and returns parsed CVE details on success' do
        response = instance_double(Net::HTTPSuccess, is_a?: true, body: sample_cve_json)
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(http_client).to receive(:get_response).and_return(response)

        result = command.execute('info', '2021-44228')

        expect(result[:cve_id]).to eq('CVE-2021-44228')
        expect(result[:severity]).to eq('CRITICAL')
        expect(result[:score]).to eq(10.0)
      end

      it 'outputs formatted CVE details to output stream' do
        response = instance_double(Net::HTTPSuccess, is_a?: true, body: sample_cve_json)
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(http_client).to receive(:get_response).and_return(response)

        command.execute('info', '2021-44228')

        expect(output.string).to include('=== CVE-2021-44228 ===')
        expect(output.string).to include('Severity:')
        expect(output.string).to include("\e[1;97;41m CRITICAL (Score: 10.0) \e[0m")
        expect(output.string).to include('Remote code execution in Apache Log4j')
        expect(logger).to have_received(:info).with('Fetching details for CVE-2021-44228...')
      end

      it 'fetches and formats GHSA advisory on success' do
        response = instance_double(Net::HTTPSuccess, is_a?: true, body: sample_ghsa_json)
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(http_client).to receive(:get_response).and_return(response)

        result = command.execute('info', 'GHSA-2j8w-xcrc-x985')

        expect(result[:id]).to eq('GHSA-2j8w-xcrc-x985')
        expect(result[:severity]).to eq('MEDIUM')
        expect(result[:score]).to eq(4.8)
        expect(output.string).to include('=== GHSA-2j8w-xcrc-x985 ===')
        expect(output.string).to include('MEDIUM (Score: 4.8)')
      end

      it 'falls back to searching repository advisory when global GHSA returns 404' do
        not_found = instance_double(Net::HTTPNotFound, is_a?: false)
        search_res = instance_double(
          Net::HTTPSuccess, is_a?: true, body: JSON.generate(items: [{ body: 'See https://github.com/rack/rack' }])
        )
        repo_adv_res = instance_double(Net::HTTPSuccess, is_a?: true, body: sample_ghsa_json)

        allow(http_client).to receive(:get_response) do |uri|
          str = uri.to_s
          if str.include?('/search/issues')
            search_res
          elsif str.include?('/repos/rack/rack')
            repo_adv_res
          else
            not_found
          end
        end

        result = command.execute('info', '2j8w-xcrc-x985')
        expect(result[:id]).to eq('GHSA-2j8w-xcrc-x985')
      end

      it 'handles 404 when CVE is not found' do
        response = instance_double(Net::HTTPNotFound, is_a?: true, code: '404')
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        allow(response).to receive(:is_a?).with(Net::HTTPNotFound).and_return(true)
        allow(http_client).to receive(:get_response).and_return(response)

        result = command.execute('info', 'CVE-1999-99999')

        expect(result).to be_nil
        expect(output.string).to include('CVE record not found: CVE-1999-99999')
      end

      it 'handles 404 when GHSA advisory is not found' do
        not_found = instance_double(Net::HTTPNotFound, is_a?: false)
        allow(not_found).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
        allow(http_client).to receive(:get_response).and_return(not_found)

        result = command.execute('info', 'GHSA-0000-0000-0000')

        expect(result).to be_nil
        expect(output.string).to include('GHSA advisory not found: GHSA-0000-0000-0000')
      end

      it 'handles network errors gracefully' do
        allow(http_client).to receive(:get_response).and_raise(SocketError, 'Connection refused')

        result = command.execute('info', 'CVE-2021-44228')

        expect(result).to be_nil
        expect(output.string).to include('Error fetching CVE-2021-44228: Connection refused')
      end
    end

    it 'can be called from another command via run_command' do
      response = instance_double(Net::HTTPSuccess, is_a?: true, body: sample_cve_json)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(Net::HTTP).to receive(:get_response).and_return(response)

      caller_cmd = Class.new(Deliverance::Commands::Base) do
        command_name 'audit_cve'

        def execute(code)
          run_command(:cve, 'info', code)
        end
      end

      result = caller_cmd.call('CVE-2021-44228', context: { output: output, logger: logger })

      expect(result[:cve_id]).to eq('CVE-2021-44228')
    end
  end
end
