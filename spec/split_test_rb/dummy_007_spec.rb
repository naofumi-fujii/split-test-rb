# frozen_string_literal: true

RSpec.describe 'DummyTests007' do
  it 'sleeps for 0.07 seconds' do
    sleep(0.07)
    expect(true).to be true
  end
end
