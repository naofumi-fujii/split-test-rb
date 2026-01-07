# frozen_string_literal: true

RSpec.describe 'DummyTests004' do
  it 'sleeps for 4 seconds' do
    sleep(4)
    expect(true).to be true
  end
end
