# frozen_string_literal: true

RSpec.describe 'DummyTests007' do
  it 'sleeps for 7 seconds' do
    sleep(7)
    expect(true).to be true
  end
end
