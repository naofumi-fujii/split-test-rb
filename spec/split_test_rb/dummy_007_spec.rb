# frozen_string_literal: true

RSpec.describe 'DummyTests007' do
  it 'sleeps for 20 seconds' do
    sleep(20)
    expect(true).to be true
  end
end
