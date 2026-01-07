# frozen_string_literal: true

RSpec.describe 'DummyTests001' do
  it 'sleeps for 0.01 seconds' do
    sleep(0.01)
    expect(true).to be true
  end
end
