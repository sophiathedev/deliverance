# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require_relative 'base'

module Deliverance
  module Commands
    class Cve < Base
      command_name 'cve'
      description 'Query CVE vulnerability information'
      usage 'cve info <CVE-ID>'

      CVE_PATTERN = /\A(?:CVE-)?(\d{4}-\d{4,})\z/i
      API_BASE_URL = 'https://cveawg.mitre.org/api/cve'
      CVSS_KEYS = %w[cvssV3_1 cvssV3_0 cvssV4_0 cvssV2_0].freeze

      def execute(subcommand = nil, cve_code = nil, *)
        case subcommand&.downcase
        when 'info'
          handle_info(cve_code)
        else
          show_usage
        end
      end

      private

      def handle_info(raw_code)
        cve_id = normalize_cve_id(raw_code)
        unless cve_id
          output.puts 'Error: Invalid CVE code format. Expected format: CVE-YYYY-NNNNN'
          return nil
        end

        logger.info("Fetching CVE details for #{cve_id}...")
        fetch_and_render_cve(cve_id)
      end

      def normalize_cve_id(raw_code)
        match = raw_code.to_s.strip.match(CVE_PATTERN)
        match ? "CVE-#{match[1]}" : nil
      end

      def fetch_and_render_cve(cve_id)
        data = fetch_cve_record(cve_id)
        return nil unless data

        info = parse_cve_record(cve_id, data)
        render_cve(info)
        info
      end

      def fetch_cve_record(cve_id)
        uri = URI("#{API_BASE_URL}/#{cve_id}")
        response = http_get(uri)

        if response.is_a?(Net::HTTPSuccess)
          JSON.parse(response.body)
        elsif response.is_a?(Net::HTTPNotFound)
          output.puts "CVE record not found: #{cve_id}"
          nil
        else
          output.puts "Failed to fetch #{cve_id}: HTTP #{response.code}"
          nil
        end
      rescue JSON::ParserError
        output.puts "Error parsing CVE API response for #{cve_id}"
        nil
      rescue StandardError => e
        output.puts "Network error fetching #{cve_id}: #{e.message}"
        nil
      end

      def http_get(uri)
        client = context[:http_client] || Net::HTTP
        client.get_response(uri)
      end

      def parse_cve_record(cve_id, data)
        cve_meta = data['cveMetadata'] || {}
        cna = data.dig('containers', 'cna') || {}
        desc = cna.dig('descriptions', 0, 'value') || 'No description available'
        severity, score = extract_severity_and_score(cna['metrics'])

        {
          cve_id: cve_id,
          state: cve_meta['state'] || 'UNKNOWN',
          assigner: cve_meta['assignerShortName'] || 'N/A',
          date_published: cve_meta['datePublished'] || 'N/A',
          title: cna['title'] || 'N/A',
          severity: severity,
          score: score,
          description: desc
        }
      end

      def extract_severity_and_score(metrics)
        cvss = find_cvss_metric(metrics)
        [cvss&.dig('baseSeverity') || 'N/A', cvss&.dig('baseScore') || 'N/A']
      end

      def find_cvss_metric(metrics)
        (metrics || []).each do |m|
          key = CVSS_KEYS.find { |k| m.key?(k) }
          return m[key] if key
        end
        nil
      end

      def render_cve(info)
        output.puts "=== #{info[:cve_id]} ==="
        output.puts "State:       #{info[:state]}"
        output.puts "Severity:    #{info[:severity]} (Score: #{info[:score]})" if info[:severity] != 'N/A'
        output.puts "Published:   #{info[:date_published]}"
        output.puts "Assigner:    #{info[:assigner]}"
        output.puts "Title:       #{info[:title]}" if info[:title] != 'N/A'
        output.puts "Description: #{info[:description]}"
      end

      def show_usage
        output.puts 'Usage: cve info <CVE-ID>'
        output.puts ''
        output.puts 'Subcommands:'
        output.puts '  info <CVE-ID>    Fetch and display information for a CVE'
        nil
      end
    end
  end
end
