# frozen_string_literal: true

RSpec.describe 'DummyTests002' do
  it 'sleeps for 0.02 seconds' do
    sleep(0.02)
    expect(true).to be true
  end
end
