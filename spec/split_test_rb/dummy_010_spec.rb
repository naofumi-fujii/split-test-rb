# frozen_string_literal: true

RSpec.describe 'DummyTests010' do
  it 'sleeps for 10 seconds' do
    sleep(10)
    expect(true).to be true
  end
end
