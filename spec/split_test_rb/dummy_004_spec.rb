# frozen_string_literal: true

RSpec.describe 'DummyTests004' do
  it 'sleeps for 0.04 seconds' do
    sleep(0.04)
    expect(true).to be true
  end
end
