# frozen_string_literal: true

RSpec.describe 'DummyTests008' do
  it 'sleeps for 0.08 seconds' do
    sleep(0.08)
    expect(true).to be true
  end
end
