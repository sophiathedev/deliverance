# frozen_string_literal: true

require_relative 'base'

module Deliverance
  module Commands
    class Clear < Base
      command_name 'clear'
      description 'Clear the terminal screen'
      usage 'clear'
      aliases :cls

      CLEAR_CODE = "\e[H\e[2J\e[3J"

      def execute(*)
        output.print CLEAR_CODE
      end
    end
  end
end
