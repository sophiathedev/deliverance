# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

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

          private

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
