# frozen_string_literal: true

RSpec.describe 'DummyTests005' do
  it 'sleeps for 0.05 seconds' do
    sleep(0.05)
    expect(true).to be true
  end
end
