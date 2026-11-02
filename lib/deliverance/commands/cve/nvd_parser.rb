# frozen_string_literal: true

module Deliverance
  module Commands
    class Cve < Base
      module NvdParser
        class << self
          def parse(data)
            vulns = data['vulnerabilities'] || []
            vulns.map { |item| parse_cve_item(item['cve'] || {}) }
          end

          def parse_cve_item(cve)
            severity, score = extract_cvss(cve['metrics'] || {})
            {
              id: cve['id'],
              ghsa_id: nil,
              mapped_cve: nil,
              published: cve['published'].to_s[0, 10],
              severity: severity,
              score: score,
              description: extract_description(cve['descriptions'] || [])
            }
          end

          private

          def extract_cvss(metrics)
            v3 = metrics['cvssMetricV31']&.first || metrics['cvssMetricV30']&.first || metrics['cvssMetricV40']&.first
            return extract_metric_data(v3) if v3

            extract_metric_data(metrics['cvssMetricV2']&.first)
          end

          def extract_metric_data(metric)
            return ['UNKNOWN', nil] unless metric

            severity = metric.dig('cvssData', 'baseSeverity') || metric['baseSeverity'] || 'UNKNOWN'
            score = metric.dig('cvssData', 'baseScore')
            [severity.upcase, score&.to_f]
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
