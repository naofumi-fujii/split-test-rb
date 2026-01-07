# frozen_string_literal: true

RSpec.describe 'DummyTests003' do
  it 'sleeps for 0.03 seconds' do
    sleep(0.03)
    expect(true).to be true
  end
end
