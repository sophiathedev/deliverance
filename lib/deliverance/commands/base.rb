# frozen_string_literal: true

module Deliverance
  module Commands
    class Base
      class << self
        def command_name(name = nil)
          if name
            old_name = @command_name || default_command_name
            Commands.unregister(old_name) if old_name
            @command_name = name.to_s.downcase
            Commands.register(self)
          end
          @command_name || default_command_name
        end

        def description(desc = nil)
          @description = desc if desc
          @description || ''
        end

        def usage(use = nil)
          @usage = use if use
          @usage || command_name
        end

        def aliases(*names)
          if names.empty?
            @aliases ||= []
          else
            @aliases = names.map { |n| n.to_s.downcase }
            Commands.register(self)
            @aliases
          end
        end

        def call(*, context: {}, **)
          new(context).execute(*, **)
        end

        def inherited(subclass)
          super
          Commands.register(subclass)
        end

        private

        def default_command_name
          return 'anonymous' unless name

          name.split('::').last.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
        end
      end

      attr_reader :context

      def initialize(context = {})
        @context = context
      end

      def execute(*_args)
        raise NotImplementedError, "#{self.class} must implement #execute"
      end

      def run_command(name, *, **)
        Commands.execute(name, *, context: context, **)
      end

      def logger
        context[:logger] || Deliverance.logger
      end

      def output
        context[:output] || $stdout
      end
    end
  end
end
