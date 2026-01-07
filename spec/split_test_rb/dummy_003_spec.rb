# frozen_string_literal: true

RSpec.describe 'DummyTests003' do
  it 'sleeps for 3 seconds' do
    sleep(3)
    expect(true).to be true
  end
end
