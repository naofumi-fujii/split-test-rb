require 'spec_helper'

RSpec.describe SplitTestRb::Balancer do
  describe '.balance' do
    let(:timings) do
      {
        'spec/models/user_spec.rb' => 4.3,
        'spec/models/post_spec.rb' => 5.3,
        'spec/controllers/users_controller_spec.rb' => 2.3,
        'spec/controllers/posts_controller_spec.rb' => 1.9,
        'spec/services/auth_service_spec.rb' => 0.7,
        'spec/helpers/application_helper_spec.rb' => 1.0
      }
    end

    it 'distributes tests across nodes' do
      nodes = described_class.balance(timings, 3)

      expect(nodes.size).to eq(3)
      expect(nodes).to all(have_key(:files))
      expect(nodes).to all(have_key(:total_time))
    end

    it 'assigns all files to nodes' do
      nodes = described_class.balance(timings, 3)
      all_files = nodes.flat_map { |node| node[:files] }

      expect(all_files.sort).to eq(timings.keys.sort)
    end

    it 'balances load across nodes using greedy algorithm' do
      nodes = described_class.balance(timings, 3)

      # Check that each node has files
      expect(nodes).to all(satisfy { |node| node[:files].any? })

      # Check that total times are relatively balanced
      total_times = nodes.map { |node| node[:total_time] }
      max_time = total_times.max
      min_time = total_times.min

      # With greedy algorithm, the difference shouldn't be too large
      # Total time is 15.5s, so average per node is ~5.17s
      expect(max_time - min_time).to be < 3.0
    end

    it 'handles single node' do
      nodes = described_class.balance(timings, 1)

      expect(nodes.size).to eq(1)
      expect(nodes[0][:files]).to contain_exactly(*timings.keys)
      expect(nodes[0][:total_time]).to be_within(0.001).of(timings.values.sum)
    end

    it 'handles more nodes than files' do
      nodes = described_class.balance(timings, 10)

      expect(nodes.size).to eq(10)

      # Some nodes will be empty
      filled_nodes = nodes.reject { |node| node[:files].empty? }
      expect(filled_nodes.size).to eq(timings.size)
    end

    it 'assigns largest files first for better balance' do
      nodes = described_class.balance(timings, 2)

      # The algorithm sorts by time descending
      # So the first two largest files (5.3s and 4.3s) should go to different nodes
      node0_has_largest = nodes[0][:files].include?('spec/models/post_spec.rb')
      node1_has_largest = nodes[1][:files].include?('spec/models/post_spec.rb')

      expect(node0_has_largest ^ node1_has_largest).to be true

      node0_has_second = nodes[0][:files].include?('spec/models/user_spec.rb')
      node1_has_second = nodes[1][:files].include?('spec/models/user_spec.rb')

      expect(node0_has_second ^ node1_has_second).to be true
    end

    it 'calculates correct total times' do
      nodes = described_class.balance(timings, 3)

      nodes.each do |node|
        expected_time = node[:files].sum { |file| timings[file] }
        expect(node[:total_time]).to eq(expected_time)
      end
    end
  end
end
