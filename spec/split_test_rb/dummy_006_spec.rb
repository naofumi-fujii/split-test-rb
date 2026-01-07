# frozen_string_literal: true

RSpec.describe 'DummyTests006' do
  it 'sleeps for 0.06 seconds' do
    sleep(0.06)
    expect(true).to be true
  end
end
