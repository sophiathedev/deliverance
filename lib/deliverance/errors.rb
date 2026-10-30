# frozen_string_literal: true

module Deliverance
  module Errors
    class Error < StandardError; end
    class CommandNotFoundError < Error; end
  end
end
