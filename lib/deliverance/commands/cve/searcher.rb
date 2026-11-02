# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'cgi'

module Deliverance
  module Commands
    class Cve < Base
      module Searcher
        SEARCH_API_URL = 'https://services.nvd.nist.gov/rest/json/cves/2.0'
        DEFAULT_RESULTS_LIMIT = 10

        class << self
          def search(keyword, client = Net::HTTP, limit: DEFAULT_RESULTS_LIMIT, start_index: 0)
            encoded = CGI.escape(keyword.to_s.strip)
            uri = URI("#{SEARCH_API_URL}?keywordSearch=#{encoded}&resultsPerPage=#{limit}&startIndex=#{start_index}")
            res = http_get(uri, client)
            return nil unless res.is_a?(Net::HTTPSuccess)

            parse_response(JSON.parse(res.body))
          rescue StandardError
            nil
          end

          private

          def http_get(uri, client)
            if client == Net::HTTP
              client.get_response(uri, { 'User-Agent' => 'Deliverance' })
            else
              client.get_response(uri)
            end
          end

          def parse_response(data)
            vulns = data['vulnerabilities'] || []
            {
              total: data['totalResults'] || vulns.size,
              items: vulns.map { |item| parse_cve_item(item['cve'] || {}) }
            }
          end

          def parse_cve_item(cve)
            severity, score = extract_cvss(cve['metrics'] || {})
            {
              id: cve['id'],
              published: cve['published'].to_s[0, 10],
              severity: severity,
              score: score,
              description: extract_description(cve['descriptions'] || [])
            }
          end

          def extract_cvss(metrics)
            v3 = metrics['cvssMetricV31']&.first || metrics['cvssMetricV30']&.first || metrics['cvssMetricV40']&.first
            return extract_metric_data(v3) if v3

            extract_metric_data(metrics['cvssMetricV2']&.first)
          end

          def extract_metric_data(metric)
            return ['UNKNOWN', nil] unless metric

            severity = metric.dig('cvssData', 'baseSeverity') || metric['baseSeverity'] || 'UNKNOWN'
            score = metric.dig('cvssData', 'baseScore')
            [severity.upcase, score]
          end

          def extract_description(descriptions)
            en = descriptions.find { |d| d['lang'] == 'en' } || descriptions.first
            en&.fetch('value', '') || ''
          end
        end
      end
    end
  end
end
