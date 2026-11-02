# frozen_string_literal: true

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

      def random(color: true, random: Random)
        render(nil, color: color, random: random)
      end

      def render(style = nil, color: true, random: Random)
        selected = style&.to_sym || random_style(random: random)
        raw_art = selected ? banner_for(selected) : nil
        return '' unless raw_art

        return raw_art unless color

        palette_color = COLORS.fetch(selected, "\e[1;36m")
        "#{palette_color}#{raw_art}#{RESET_COLOR}"
      end
    end
  end
end
