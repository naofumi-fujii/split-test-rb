# frozen_string_literal: true

RSpec.describe 'DummyTests009' do
  it 'sleeps for 9 seconds' do
    sleep(9)
    expect(true).to be true
  end
end
