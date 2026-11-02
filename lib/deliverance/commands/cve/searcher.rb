# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'cgi'
require_relative 'nvd_parser'

module Deliverance
  module Commands
    class Cve < Base
      module Searcher
        SEARCH_API_URL = 'https://services.nvd.nist.gov/rest/json/cves/2.0'
        DEFAULT_RESULTS_LIMIT = 10

        class << self
          def search(keyword, client = Net::HTTP, limit: DEFAULT_RESULTS_LIMIT, start_index: 0)
            items = cached_search(keyword, client)
            return nil unless items

            {
              total: items.size,
              items: items[start_index, limit] || []
            }
          end

          def reset_cache!
            @cache = {}
          end

          private

          def cached_search(keyword, client)
            @cache ||= {}
            key = "#{client.object_id}:#{keyword}"
            @cache[key] ||= fetch_and_merge(keyword, client)
          end

          def fetch_and_merge(keyword, client)
            cve_thread = Thread.new { fetch_nvd(keyword, client) }
            ghsa_thread = Thread.new { GhsaFetcher.search(keyword, client) }

            cve_items = cve_thread.value
            ghsa_items = ghsa_thread.value
            return nil if cve_items.nil? && ghsa_items.nil?

            merge_and_sort(cve_items || [], ghsa_items || [])
          end

          def fetch_nvd(keyword, client)
            encoded = CGI.escape(keyword.to_s.strip)
            uri = URI("#{SEARCH_API_URL}?keywordSearch=#{encoded}&resultsPerPage=50")
            res = http_get(uri, client)
            return nil unless res.is_a?(Net::HTTPSuccess)

            NvdParser.parse(JSON.parse(res.body))
          rescue StandardError
            nil
          end

          def merge_and_sort(cve_items, ghsa_items)
            by_cve = {}
            unmapped_ghsa = []

            cve_items.each { |item| by_cve[item[:id]] = item }
            ghsa_items.each { |ghsa| merge_ghsa_item(by_cve, unmapped_ghsa, ghsa) }

            sort_by_cvss_desc(by_cve.values + unmapped_ghsa)
          end

          def merge_ghsa_item(by_cve, unmapped_ghsa, ghsa)
            cve_id = ghsa[:mapped_cve]
            if cve_id && by_cve[cve_id]
              existing = by_cve[cve_id]
              existing[:ghsa_id] = ghsa[:ghsa_id]
              existing[:score] ||= ghsa[:score]
              existing[:severity] = ghsa[:severity] if existing[:severity] == 'UNKNOWN'
            elsif cve_id
              by_cve[cve_id] = ghsa.merge(id: cve_id)
            else
              unmapped_ghsa << ghsa
            end
          end

          def sort_by_cvss_desc(items)
            items.sort_by do |item|
              score = Float(item[:score], exception: false)
              [score ? -score : Float::INFINITY, item[:id].to_s]
            end
          end

          def http_get(uri, client)
            if client == Net::HTTP
              client.get_response(uri, { 'User-Agent' => 'Deliverance' })
            else
              client.get_response(uri)
            end
          end
        end
      end
    end
  end
end
