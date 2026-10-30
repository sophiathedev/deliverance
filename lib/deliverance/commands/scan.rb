# frozen_string_literal: true

require_relative 'base'

module Deliverance
  module Commands
    class Scan < Base
      command_name 'scan'
      description 'Scan a path or glob pattern for files and directories'
      usage 'scan <path>'
      aliases :s

      def execute(target = nil, *extra_args)
        path = resolve_target_path(target, extra_args)
        return unless path

        logger.info("Starting scan for: #{path}")
        entries = discover_entries(path)
        stats = build_stats(path, entries)

        log_verbose_stats(stats)
        render_summary(stats)
        stats
      end

      private

      def resolve_target_path(target, extra_args)
        if target.nil? || target.strip.empty?
          output.puts 'Usage: scan <path>'
          logger.warn('Scan aborted: no path provided')
          return nil
        end

        raw = [target, *extra_args].join(' ')
        clean_path = raw.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
        clean_path = clean_path.unicode_normalize(:nfc) if clean_path.respond_to?(:unicode_normalize)
        File.expand_path(clean_path)
      end

      def discover_entries(path)
        if File.directory?(path)
          Dir.glob(File.join(path, '**/*'))
        elsif File.file?(path)
          [path]
        else
          Dir.glob(path)
        end
      end

      def build_stats(path, entries)
        files = []
        dirs = []
        total_bytes = 0

        entries.each do |entry|
          if File.file?(entry)
            files << entry
            total_bytes += file_size(entry)
          elsif File.directory?(entry)
            dirs << entry
          end
        end

        {
          target: path,
          total_objects: entries.size,
          files: files,
          directories: dirs,
          total_bytes: total_bytes
        }
      end

      def file_size(entry)
        File.size(entry)
      rescue SystemCallError
        0
      end

      def log_verbose_stats(stats)
        logger.info(
          "Scan completed: #{stats[:total_objects]} objects found " \
          "(#{stats[:files].size} files, #{stats[:directories].size} directories)"
        )
      end

      def render_summary(stats)
        output.puts "Scan summary for: #{stats[:target]}"
        output.puts "  Total objects: #{stats[:total_objects]}"
        output.puts "  Files:         #{stats[:files].size} (~#{format_bytes(stats[:total_bytes])})"
        output.puts "  Directories:   #{stats[:directories].size}"
      end

      def format_bytes(bytes)
        if bytes < 1024
          "#{bytes} B"
        elsif bytes < 1024 * 1024
          format('%.1f KB', bytes / 1024.0)
        else
          format('%.2f MB', bytes / (1024.0 * 1024.0))
        end
      end
    end
  end
end
