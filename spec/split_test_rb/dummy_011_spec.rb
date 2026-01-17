# frozen_string_literal: true

RSpec.describe 'DummyTests011' do
  it 'sleeps for 45 seconds' do
    sleep(45)
    expect(true).to be true
  end
end
