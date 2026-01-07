# frozen_string_literal: true

RSpec.describe 'DummyTests008' do
  it 'sleeps for 8 seconds' do
    sleep(8)
    expect(true).to be true
  end
end
