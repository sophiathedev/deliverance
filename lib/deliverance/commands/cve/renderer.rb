# frozen_string_literal: true

module Deliverance
  module Commands
    class Cve < Base
      module Renderer
        SEVERITY_STYLES = {
          'CRITICAL' => "\e[1;97;41m",
          'HIGH' => "\e[1;97;45m",
          'MEDIUM' => "\e[1;30;43m",
          'LOW' => "\e[1;97;44m",
          'NONE' => "\e[1;97;100m",
          'UNKNOWN' => "\e[1;97;100m"
        }.freeze

        class << self
          def render_advisory(info, output)
            output.puts "\e[1;36m=== #{info[:id]} ===\e[0m"
            output.puts "\e[1mMapped CVE:\e[0m  #{info[:mapped_cve]}" if info[:mapped_cve]
            output.puts "\e[1mState:\e[0m       #{format_state(info[:state])}"
            render_severity(info, output)
            render_metadata(info, output)
            output.puts "\e[1mTitle:\e[0m       \e[1m#{info[:title]}\e[0m" if info[:title] != 'N/A'
            output.puts "\e[1mDescription:\e[0m #{info[:description]}"
          end

          def render_search(results, keyword, output)
            items = results[:items] || []
            if items.empty?
              output.puts "No CVEs found matching '#{keyword}'"
              return
            end

            output.puts "Found #{results[:total]} CVE(s) matching '#{keyword}':\n\n"
            items.each_with_index do |item, idx|
              render_search_item(idx + 1, item, keyword, output)
            end
          end

          def highlight(text, keyword, base_color: nil)
            return '' if text.nil? || text.empty?

            words = keyword.to_s.strip.split(/\s+/).reject(&:empty?)
            return text if words.empty?

            pattern = Regexp.union(words.map { |w| Regexp.new(Regexp.escape(w), Regexp::IGNORECASE) })
            reset = base_color ? "\e[0m#{base_color}" : "\e[0m"
            text.gsub(pattern, "\e[1;31m\\0#{reset}")
          end

          def severity_badge(severity, score)
            sev = severity.to_s.upcase
            style = SEVERITY_STYLES[sev] || SEVERITY_STYLES['UNKNOWN']
            score_text = score && score != 'N/A' ? " (Score: #{score})" : ''
            "#{style} #{sev}#{score_text} \e[0m"
          end

          def format_state(state)
            case state.to_s.upcase
            when 'PUBLISHED' then "\e[1;32m#{state}\e[0m"
            when 'REJECTED' then "\e[1;31m#{state}\e[0m"
            else "\e[1;33m#{state}\e[0m"
            end
          end

          private

          def render_severity(info, output)
            return if info[:severity] == 'N/A'

            badge = severity_badge(info[:severity], info[:score])
            output.puts "\e[1mSeverity:\e[0m    #{badge}"
          end

          def render_metadata(info, output)
            output.puts "\e[1mPublished:\e[0m   #{info[:published]}"
            output.puts "\e[1mPackages:\e[0m    \e[36m#{info[:packages]}\e[0m" if info[:packages]
            output.puts "\e[1mAssigner:\e[0m    \e[35m#{info[:assigner]}\e[0m" if info[:assigner] != 'N/A'
          end

          def render_search_item(index, item, keyword, output)
            id_str = highlight(item[:id].to_s, keyword, base_color: "\e[1;36m")
            badge = severity_badge(item[:severity], item[:score])
            published = item[:published] ? "  \e[90m(#{item[:published]})\e[0m" : ''

            output.puts "[#{index}] \e[1;36m#{id_str}\e[0m  #{badge}#{published}"
            render_search_description(item[:description], keyword, output)
          end

          def render_search_description(description, keyword, output)
            if description && !description.empty?
              desc = highlight(description, keyword)
              output.puts "    #{desc}\n\n"
            else
              output.puts
            end
          end
        end
      end
    end
  end
end
