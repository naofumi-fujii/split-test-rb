# frozen_string_literal: true

RSpec.describe 'DummyTests009' do
  it 'sleeps for 0.09 seconds' do
    sleep(0.09)
    expect(true).to be true
  end
end
