# frozen_string_literal: true

RSpec.describe 'DummyTests001' do
  it 'sleeps for 1 seconds' do
    sleep(1)
    expect(true).to be true
  end
end
