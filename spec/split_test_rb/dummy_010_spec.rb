# frozen_string_literal: true

RSpec.describe 'DummyTests010' do
  it 'sleeps for 40 seconds' do
    sleep(40)
    expect(true).to be true
  end
end
