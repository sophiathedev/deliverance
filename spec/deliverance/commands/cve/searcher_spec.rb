# frozen_string_literal: true

RSpec.describe Deliverance::Commands::Cve::Searcher do
  let(:client) { class_double(Net::HTTP) }
  let(:empty_json) { instance_double(Net::HTTPSuccess, is_a?: true, body: '[]') }

  def cvss_metric(score)
    { 'cvssData' => { 'baseScore' => score } }
  end

  before do
    described_class.reset_cache!
  end

  describe '.search' do
    let(:nvd_data) do
      {
        'vulnerabilities' => [
          { 'cve' => { 'id' => 'CVE-2023-0001', 'metrics' => { 'cvssMetricV31' => [cvss_metric(5.5)] } } },
          { 'cve' => { 'id' => 'CVE-2023-0002', 'metrics' => { 'cvssMetricV31' => [cvss_metric(9.8)] } } }
        ]
      }
    end
    let(:ghsa_data) do
      [{ 'ghsa_id' => 'GHSA-aaaa-bbbb-cccc', 'severity' => 'critical', 'cvss' => { 'score' => 10.0 } }]
    end

    it 'sorts search results by CVSS score descending' do
      nvd_res = instance_double(Net::HTTPSuccess, is_a?: true, body: JSON.generate(nvd_data))
      gh_res = instance_double(Net::HTTPSuccess, is_a?: true, body: JSON.generate(ghsa_data))
      allow(client).to receive(:get_response) { |u| u.to_s.include?('nist.gov') ? nvd_res : gh_res }

      results = described_class.search('rails', client)

      expect(results[:items].map { |i| i[:score] }).to eq([10.0, 9.8, 5.5])
      expect(results[:items].map { |i| i[:id] }).to eq(%w[GHSA-aaaa-bbbb-cccc CVE-2023-0002 CVE-2023-0001])
    end

    it 'merges and deduplicates GHSA advisories mapping to existing CVEs' do
      nvd = { 'vulnerabilities' => [{ 'cve' => { 'id' => 'CVE-2021-44228', 'metrics' => {} } }] }
      gh = [{ 'ghsa_id' => 'GHSA-jfh8-c2jp-5v3q', 'cve_id' => 'CVE-2021-44228', 'cvss' => { 'score' => 10.0 } }]
      nvd_res = instance_double(Net::HTTPSuccess, is_a?: true, body: JSON.generate(nvd))
      gh_res = instance_double(Net::HTTPSuccess, is_a?: true, body: JSON.generate(gh))
      allow(client).to receive(:get_response) { |u| u.to_s.include?('nist.gov') ? nvd_res : gh_res }

      item = described_class.search('log4j', client)[:items].first

      expect(item[:id]).to eq('CVE-2021-44228')
      expect(item[:ghsa_id]).to eq('GHSA-jfh8-c2jp-5v3q')
      expect(item[:score]).to eq(10.0)
    end

    it 'returns cached results on repeated queries with the same client' do
      allow(client).to receive(:get_response).and_return(empty_json)

      described_class.search('ruby', client)
      described_class.search('ruby', client)

      expect(client).to have_received(:get_response).twice
    end
  end
end
