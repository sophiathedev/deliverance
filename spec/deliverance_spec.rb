# frozen_string_literal: true

RSpec.describe Deliverance do
  it 'has a version number' do
    expect(Deliverance::VERSION).not_to be_nil
  end

  it 'defines a standard error class' do
    expect(Deliverance::Error.new).to be_a(StandardError)
  end
end

