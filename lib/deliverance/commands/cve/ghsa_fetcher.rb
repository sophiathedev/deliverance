# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'cgi'

module Deliverance
  module Commands
    class Cve < Base
      module GhsaFetcher
        GLOBAL_API_URL = 'https://api.github.com/advisories'

        class << self
          def fetch(ghsa_id, client = Net::HTTP)
            res = http_get(URI("#{GLOBAL_API_URL}/#{ghsa_id}"), client)
            return JSON.parse(res.body) if res.is_a?(Net::HTTPSuccess)

            find_repo_advisory(ghsa_id, client)
          rescue StandardError
            nil
          end

          def search(keyword, client = Net::HTTP)
            raw = fetch_advisories_for_keyword(keyword, client)
            return nil unless raw

            raw.map { |item| parse_ghsa_search_item(item) }
          rescue StandardError
            nil
          end

          def http_get(uri, client)
            if client == Net::HTTP
              client.get_response(uri, { 'User-Agent' => 'Deliverance' })
            else
              client.get_response(uri)
            end
          end

          private

          def fetch_advisories_for_keyword(keyword, client)
            kw = keyword.to_s.strip
            return [] if kw.empty?

            uri = advisory_search_uri(kw)
            res = http_get(uri, client)
            return JSON.parse(res.body) if res.is_a?(Net::HTTPSuccess)

            nil
          end

          def advisory_search_uri(keyword)
            if (m = keyword.match(GHSA_PATTERN))
              URI("#{GLOBAL_API_URL}?ghsa_id=GHSA-#{m[1]}")
            elsif (m = keyword.match(CVE_PATTERN))
              URI("#{GLOBAL_API_URL}?cve_id=CVE-#{m[1]}")
            else
              param = CGI.escape(keyword.split.first)
              URI("#{GLOBAL_API_URL}?affects=#{param}&per_page=50")
            end
          end

          def parse_ghsa_search_item(item)
            cvss = item['cvss'] || item.dig('cvss_severities', 'cvss_v3') || {}
            score = cvss['score']&.to_f
            {
              id: item['ghsa_id'],
              ghsa_id: item['ghsa_id'],
              mapped_cve: item['cve_id'],
              published: item['published_at'].to_s[0, 10],
              severity: (item['severity'] || 'UNKNOWN').upcase,
              score: score,
              description: item['summary'] || item['description'] || ''
            }
          end

          def find_repo_advisory(ghsa_id, client)
            search_uri = URI("https://api.github.com/search/issues?q=#{ghsa_id}")
            res = http_get(search_uri, client)
            return nil unless res.is_a?(Net::HTTPSuccess)

            extract_repos(JSON.parse(res.body)).each do |repo|
              adv_uri = URI("https://api.github.com/repos/#{repo}/security-advisories/#{ghsa_id}")
              adv_res = http_get(adv_uri, client)
              return JSON.parse(adv_res.body) if adv_res.is_a?(Net::HTTPSuccess)
            end
            nil
          end

          def extract_repos(data)
            repos = []
            (data['items'] || []).first(10).each do |item|
              "#{item['body']} #{item['html_url']}".scan(%r{github\.com/([\w.-]+/[\w.-]+)}).each do |m|
                r = m.first.delete_suffix('.git')
                repos << r unless repos.include?(r) || r.start_with?('advisories/')
              end
            end
            repos.first(5)
          end
        end
      end
    end
  end
end
