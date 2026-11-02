# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require_relative 'base'
require_relative 'cve/ghsa_fetcher'

module Deliverance
  module Commands
    class Cve < Base
      command_name 'cve'
      description 'Query CVE / GHSA vulnerability information'
      usage 'cve info <CVE-ID | GHSA-ID>'

      CVE_PATTERN = /\A(?:CVE-)?(\d{4}-\d{4,})\z/i
      GHSA_PATTERN = /\A(?:GHSA-)?([a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4})\z/i
      CVE_API_URL = 'https://cveawg.mitre.org/api/cve'
      CVSS_KEYS = %w[cvssV3_1 cvssV3_0 cvssV4_0 cvssV2_0].freeze

      SEVERITY_STYLES = {
        'CRITICAL' => "\e[1;97;41m",
        'HIGH' => "\e[1;97;45m",
        'MEDIUM' => "\e[1;30;43m",
        'LOW' => "\e[1;97;44m",
        'NONE' => "\e[1;97;100m"
      }.freeze

      def execute(subcommand = nil, code = nil, *)
        if subcommand&.downcase == 'info'
          handle_info(code)
        else
          show_usage
        end
      end

      private

      def handle_info(raw_code)
        type, id = detect_identifier(raw_code)
        unless type
          output.puts 'Error: Invalid code format. ' \
                      'Expected CVE (e.g. CVE-2021-44228) or GHSA (e.g. GHSA-2j8w-xcrc-x985)'
          return nil
        end

        logger.info("Fetching details for #{id}...")
        data = type == :cve ? fetch_cve(id) : fetch_ghsa(id)
        return nil unless data

        info = type == :cve ? parse_cve(id, data) : parse_ghsa(id, data)
        render_advisory(info)
        info
      end

      def detect_identifier(code)
        str = code.to_s.strip
        if (m = str.match(CVE_PATTERN))
          [:cve, "CVE-#{m[1]}"]
        elsif (m = str.match(GHSA_PATTERN))
          [:ghsa, "GHSA-#{m[1].downcase}"]
        end
      end

      def fetch_cve(cve_id)
        res = http_get(URI("#{CVE_API_URL}/#{cve_id}"))
        if res.is_a?(Net::HTTPSuccess)
          JSON.parse(res.body)
        else
          output.puts res.is_a?(Net::HTTPNotFound) ? "CVE record not found: #{cve_id}" : "HTTP error: #{res.code}"
          nil
        end
      rescue StandardError => e
        output.puts "Error fetching #{cve_id}: #{e.message}"
        nil
      end

      def fetch_ghsa(ghsa_id)
        data = GhsaFetcher.fetch(ghsa_id, http_client)
        output.puts "GHSA advisory not found: #{ghsa_id}" unless data
        data
      end

      def http_client
        context[:http_client] || Net::HTTP
      end

      def http_get(uri)
        if http_client == Net::HTTP
          http_client.get_response(uri, { 'User-Agent' => 'Deliverance' })
        else
          http_client.get_response(uri)
        end
      end

      def parse_cve(cve_id, data)
        cve_meta = data['cveMetadata'] || {}
        cna = data.dig('containers', 'cna') || {}
        severity, score = extract_cvss(cna['metrics'])
        {
          cve_id: cve_id,
          id: cve_id,
          state: cve_meta['state'] || 'UNKNOWN',
          assigner: cve_meta['assignerShortName'] || 'N/A',
          published: cve_meta['datePublished'] || 'N/A',
          title: cna['title'] || 'N/A',
          severity: severity,
          score: score,
          description: cna.dig('descriptions', 0, 'value') || 'No description available'
        }
      end

      def parse_ghsa(ghsa_id, data)
        cvss = data['cvss'] || data.dig('cvss_severities', 'cvss_v3') || {}
        {
          cve_id: ghsa_id,
          id: ghsa_id,
          mapped_cve: data['cve_id'],
          state: (data['state'] || 'PUBLISHED').upcase,
          assigner: 'GitHub',
          published: data['published_at'] || 'N/A',
          title: data['summary'] || 'N/A',
          severity: data['severity']&.upcase || 'N/A',
          score: cvss['score'] || 'N/A',
          packages: extract_ghsa_packages(data),
          description: data['description'] || 'No description available'
        }
      end

      def extract_ghsa_packages(data)
        pkgs = (data['vulnerabilities'] || []).filter_map { |v| v.dig('package', 'name') }.uniq
        pkgs.empty? ? nil : pkgs.join(', ')
      end

      def extract_cvss(metrics)
        cvss = nil
        (metrics || []).each do |m|
          key = CVSS_KEYS.find { |k| m.key?(k) }
          cvss = m[key] if key
          break if cvss
        end
        [cvss&.dig('baseSeverity') || 'N/A', cvss&.dig('baseScore') || 'N/A']
      end

      def render_advisory(info)
        output.puts "\e[1;36m=== #{info[:id]} ===\e[0m"
        output.puts "\e[1mMapped CVE:\e[0m  #{info[:mapped_cve]}" if info[:mapped_cve]
        output.puts "\e[1mState:\e[0m       #{format_state(info[:state])}"
        render_severity(info)
        render_metadata(info)
        output.puts "\e[1mTitle:\e[0m       \e[1m#{info[:title]}\e[0m" if info[:title] != 'N/A'
        output.puts "\e[1mDescription:\e[0m #{info[:description]}"
      end

      def render_metadata(info)
        output.puts "\e[1mPublished:\e[0m   #{info[:published]}"
        output.puts "\e[1mPackages:\e[0m    \e[36m#{info[:packages]}\e[0m" if info[:packages]
        output.puts "\e[1mAssigner:\e[0m    \e[35m#{info[:assigner]}\e[0m" if info[:assigner] != 'N/A'
      end

      def render_severity(info)
        return if info[:severity] == 'N/A'

        style = SEVERITY_STYLES[info[:severity].to_s.upcase] || "\e[1;97;100m"
        score_text = info[:score] == 'N/A' ? '' : " (Score: #{info[:score]})"
        output.puts "\e[1mSeverity:\e[0m    #{style} #{info[:severity]}#{score_text} \e[0m"
      end

      def format_state(state)
        case state.to_s.upcase
        when 'PUBLISHED' then "\e[1;32m#{state}\e[0m"
        when 'REJECTED' then "\e[1;31m#{state}\e[0m"
        else "\e[1;33m#{state}\e[0m"
        end
      end

      def show_usage
        output.puts 'Usage: cve info <CVE-ID | GHSA-ID>'
        output.puts ''
        output.puts 'Subcommands:'
        output.puts '  info <ID>    Fetch details for a CVE or GitHub Security Advisory (GHSA)'
        nil
      end
    end
  end
end
