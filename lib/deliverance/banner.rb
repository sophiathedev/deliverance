# frozen_string_literal: true

require_relative 'version'

module Deliverance
  module Banner
    BANNERS_DIR = File.expand_path('banners', __dir__)
    RESET_COLOR = "\e[0m"

    COLORS = {
      bubble: "\e[1;92m",
      chunky: "\e[1;96m",
      doom: "\e[1;91m",
      graffiti: "\e[1;95m",
      slant: "\e[1;36m",
      small: "\e[1;35m",
      speed: "\e[1;33m",
      standard: "\e[1;32m"
    }.freeze

    QUOTES = [
      'Delivering peace of mind, one exploit at a time.',
      'Special delivery: zero days and zero bugs (hopefully).',
      'Signed, sealed, delivered - vulnerabilities revealed.',
      'There is no place like 127.0.0.1.',
      'Because every bug deserves a swift deliverance.',
      "Keep calm and 'scan' on.",
      'Delivering clean code and fixing CVEs since day one.',
      'Drop packets, not expectations.',
      'It works on my machine, delivering to yours.'
    ].freeze

    class << self
      def styles
        @styles ||= Dir.glob(File.join(BANNERS_DIR, '*.txt')).map do |path|
          File.basename(path, '.txt').to_sym
        end.sort.freeze
      end

      def banner_for(style)
        @banners ||= {}
        @banners[style] ||= begin
          path = File.join(BANNERS_DIR, "#{style}.txt")
          File.exist?(path) ? File.read(path, encoding: 'UTF-8').chomp : nil
        end
      end

      def random_style(random: Random)
        styles.sample(random: random)
      end

      def random_quote(random: Random)
        QUOTES.sample(random: random)
      end

      def random(color: true, random: Random)
        render(nil, color: color, random: random)
      end

      def info_line(color: true, random: Random)
        version_tag = "v#{Deliverance::VERSION}"
        quote = random_quote(random: random)
        return "  #{version_tag} ~ \"#{quote}\"" unless color

        "  \e[2;37m#{version_tag}\e[0m \e[90m~\e[0m \e[3;37m\"#{quote}\"\e[0m"
      end

      def render(style = nil, color: true, random: Random)
        selected = style&.to_sym || random_style(random: random)
        raw_art = selected ? banner_for(selected) : nil
        return '' unless raw_art

        art = color ? "#{COLORS.fetch(selected, "\e[1;36m")}#{raw_art}#{RESET_COLOR}" : raw_art
        "#{art}\n#{info_line(color: color, random: random)}"
      end
    end
  end
end
