# frozen_string_literal: true

RSpec.describe 'DummyTests009' do
  it 'sleeps for 30 seconds' do
    sleep(30)
    expect(true).to be true
  end
end
