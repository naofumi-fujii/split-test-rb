# frozen_string_literal: true

RSpec.describe 'DummyTests002' do
  it 'sleeps for 2 seconds' do
    sleep(2)
    expect(true).to be true
  end
end
