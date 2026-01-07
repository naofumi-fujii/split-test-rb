# frozen_string_literal: true

RSpec.describe 'DummyTests006' do
  it 'sleeps for 15 seconds' do
    sleep(15)
    expect(true).to be true
  end
end
