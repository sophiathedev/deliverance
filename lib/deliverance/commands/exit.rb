# frozen_string_literal: true

require_relative 'base'

module Deliverance
  module Commands
    class Exit < Base
      description 'Exit the interactive CLI'
      usage 'exit'
      aliases :quit

      def execute(*)
        throw :exit_repl
      end
    end
  end
end
