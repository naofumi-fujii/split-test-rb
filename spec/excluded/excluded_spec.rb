# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Excluded specs' do
  it 'should be excluded from parallel test distribution' do
    # This spec exists to demonstrate --exclude-pattern functionality
    # If this spec runs in the parallel-test job, the exclusion is not working
    expect(true).to be true
  end

  it 'verifies exclude pattern works correctly' do
    expect(1 + 1).to eq 2
  end
end
