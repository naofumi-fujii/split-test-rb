# frozen_string_literal: true

RSpec.describe 'DummyTests006' do
  it 'sleeps for 6 seconds' do
    sleep(6)
    expect(true).to be true
  end
end
