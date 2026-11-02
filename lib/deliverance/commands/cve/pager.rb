# frozen_string_literal: true

require 'io/console'

module Deliverance
  module Commands
    class Cve < Base
      module Pager
        PAGE_SIZE = 10
        CLEAR_CODE = "\e[H\e[2J"
        PAGE_NAV_KEYS = %i[right left].freeze
        KEY_MAP = {
          'q' => :quit, 'Q' => :quit, "\u0003" => :quit,
          'l' => :right, 'L' => :right, 'n' => :right, 'N' => :right,
          'h' => :left, 'H' => :left, 'p' => :left, 'P' => :left
        }.freeze

        class << self
          def paginate(initial_results, keyword, context, client = Net::HTTP)
            total = initial_results[:total].to_i
            input = context[:input] || $stdin
            total_pages = (total.to_f / PAGE_SIZE).ceil

            if total <= PAGE_SIZE || total_pages <= 1 || !interactive?(input)
              Renderer.render_search(initial_results, keyword, context[:output] || $stdout)
              return initial_results
            end

            run_pager(initial_results, keyword, context, client, total_pages)
          end

          def interactive?(input)
            return false if input.respond_to?(:tty?) && !input.tty?

            input.respond_to?(:getch)
          end

          def read_key(input)
            char = input.getch
            return nil unless char

            case char
            when "\e[C", "\eOC" then :right
            when "\e[D", "\eOD" then :left
            when "\e" then read_escape_sequence(input)
            else KEY_MAP.fetch(char, :unknown)
            end
          end

          private

          def run_pager(initial_results, keyword, context, client, total_pages)
            pages = { 1 => initial_results }
            page = 1
            out = context[:output] || $stdout
            prefetch = nil

            loop do
              prefetch&.join if prefetch&.alive?
              render_page(fetch_page(keyword, client, page, pages), keyword, out, page, total_pages)
              prefetch = prefetch_next(keyword, client, page + 1, total_pages, pages)
              out.print pager_prompt(page, total_pages, initial_results[:total])
              key = read_key(context[:input] || $stdin)
              break if key == :quit || key.nil?

              page = next_page_for(key, page, total_pages)
              out.print CLEAR_CODE if PAGE_NAV_KEYS.include?(key)
            end
            prefetch&.kill if prefetch&.alive?
            out.puts
            initial_results
          end

          def prefetch_next(keyword, client, next_page, total_pages, pages)
            return nil if next_page > total_pages || pages.key?(next_page)

            Thread.new do
              pages[next_page] ||= fetch_page(keyword, client, next_page, pages)
            end
          end

          def fetch_page(keyword, client, page, pages)
            pages[page] ||= Searcher.search(
              keyword, client, limit: PAGE_SIZE, start_index: (page - 1) * PAGE_SIZE
            ) || { total: 0, items: [] }
          end

          def render_page(results, keyword, output, page, total_pages)
            pagination = { page: page, total_pages: total_pages, start_index: (page - 1) * PAGE_SIZE }
            Renderer.render_search(results, keyword, output, pagination: pagination)
          end

          def pager_prompt(page, total_pages, total)
            "\e[1;33m-- Page #{page}/#{total_pages} (#{total} CVEs) " \
              "| [<-] Prev | [->] Next | [q] Quit --\e[0m "
          end

          def next_page_for(key, current_page, total_pages)
            case key
            when :right then [current_page + 1, total_pages].min
            when :left then [current_page - 1, 1].max
            else current_page
            end
          end

          def read_escape_sequence(input)
            return :escape unless input.respond_to?(:read_nonblock)
            return :escape unless input.respond_to?(:wait_readable) && input.wait_readable(0.05)

            case input.read_nonblock(2, exception: false)
            when '[C', 'OC' then :right
            when '[D', 'OD' then :left
            else :escape
            end
          rescue StandardError
            :escape
          end
        end
      end
    end
  end
end
