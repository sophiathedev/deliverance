# frozen_string_literal: true

module Deliverance
  module Commands
    class << self
      def registry
        @registry ||= {}
      end

      def register(command_class)
        primary_name = command_class.command_name
        registry[primary_name] = command_class

        command_class.aliases.each do |alias_name|
          registry[alias_name] = command_class
        end
      end

      def unregister(name)
        registry.delete(name.to_s.downcase)
      end

      def find(name)
        registry[name.to_s.downcase]
      end

      def all
        registry.values.uniq
      end

      def execute(name, *, context: {}, **)
        command_class = find(name)
        raise Errors::CommandNotFoundError, "Unknown command: '#{name}'" unless command_class

        command_class.new(context).execute(*, **)
      end

      def reset_registry!
        @registry = {}
        register(Help)
        register(Exit)
        register(Scan)
      end
    end
  end
end

require_relative 'commands/base'
require_relative 'commands/help'
require_relative 'commands/exit'
require_relative 'commands/scan'
