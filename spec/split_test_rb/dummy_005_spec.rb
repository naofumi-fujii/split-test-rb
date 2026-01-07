# frozen_string_literal: true

RSpec.describe 'DummyTests005' do
  it 'sleeps for 5 seconds' do
    sleep(5)
    expect(true).to be true
  end
end
