# frozen_string_literal: true

require_relative 'base'

module Deliverance
  module Commands
    class Help < Base
      description 'List available commands or show details for a specific command'
      usage 'help [command]'
      aliases 'h', '?'

      def execute(command_name = nil)
        if command_name.nil? || command_name.empty?
          list_all_commands
        else
          show_command_help(command_name)
        end
      end

      private

      def list_all_commands
        commands = Commands.all.sort_by(&:command_name)
        output.puts 'Available commands:'

        max_usage = commands.map { |cmd| cmd.usage.length }.max || 10
        commands.each do |cmd|
          output.puts format("  %-#{max_usage}s  %s", cmd.usage, summary_for(cmd))
        end
      end

      def summary_for(cmd)
        summary = cmd.description.to_s
        summary += " (aliases: #{cmd.aliases.join(', ')})" unless cmd.aliases.empty?
        summary
      end

      def show_command_help(name)
        cmd = Commands.find(name)
        unless cmd
          output.puts "Command '#{name}' not found. Type 'help' to see all commands."
          return
        end

        output.puts "Command:     #{cmd.command_name}"
        output.puts "Usage:       #{cmd.usage}"
        output.puts "Aliases:     #{cmd.aliases.join(', ')}" unless cmd.aliases.empty?
        output.puts "Description: #{cmd.description}" if cmd.description && !cmd.description.empty?
      end
    end
  end
end
