# frozen_string_literal: true

RSpec.describe 'DummyTests008' do
  it 'sleeps for 25 seconds' do
    sleep(25)
    expect(true).to be true
  end
end
