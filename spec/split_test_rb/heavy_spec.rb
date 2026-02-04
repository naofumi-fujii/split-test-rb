# frozen_string_literal: true

# Heavy test file for demonstrating --split-by-example-threshold feature.
# This file contains multiple examples that can be split across CI nodes
# when the total execution time exceeds the threshold.
RSpec.describe 'HeavyTests' do
  it 'example 1 - sleeps for 1 second' do
    sleep(1)
    expect(1).to eq 1
  end

  it 'example 2 - sleeps for 1 second' do
    sleep(1)
    expect(2).to eq 2
  end

  it 'example 3 - sleeps for 1 second' do
    sleep(1)
    expect(3).to eq 3
  end
end
