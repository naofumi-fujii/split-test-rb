require 'spec_helper'

RSpec.describe SplitTestRb::CLI do
  let(:fixture_path) { File.expand_path('../fixtures/sample_junit.xml', __dir__) }

  describe '.run' do
    it 'outputs files for specified node' do
      argv = ['--xml-path', fixture_path, '--node-index', '0', '--node-total', '2']

      expect do
        described_class.run(argv)
      end.to output(/spec\//).to_stdout
    end

    it 'exits with error when xml-path is missing' do
      argv = []

      expect do
        expect { described_class.run(argv) }.to raise_error(SystemExit)
      end.to output(/Error: --xml-path is required/).to_stderr
    end

    it 'falls back to all spec files when XML file does not exist' do
      argv = ['--xml-path', 'nonexistent.xml', '--node-index', '0', '--node-total', '1']

      stdout_output = capture_stdout do
        capture_stderr do
          described_class.run(argv)
        end
      end

      # Should output spec files from the current project
      expect(stdout_output).to match(/spec\//)
    end

    it 'outputs different files for different nodes' do
      node0_output = capture_stdout do
        described_class.run(['--xml-path', fixture_path, '--node-index', '0', '--node-total', '2'])
      end

      node1_output = capture_stdout do
        described_class.run(['--xml-path', fixture_path, '--node-index', '1', '--node-total', '2'])
      end

      node0_files = node0_output.strip.split("\n")
      node1_files = node1_output.strip.split("\n")

      # Files should not overlap
      expect(node0_files & node1_files).to be_empty

      # Combined should include all files
      all_files = (node0_files + node1_files).sort
      expect(all_files).to include(
        'spec/models/user_spec.rb',
        'spec/models/post_spec.rb',
        'spec/controllers/users_controller_spec.rb',
        'spec/controllers/posts_controller_spec.rb',
        'spec/services/auth_service_spec.rb',
        'spec/helpers/application_helper_spec.rb'
      )
    end
  end

  describe '.parse_options' do
    it 'parses node-index option' do
      options = described_class.parse_options(['--node-index', '2'])
      expect(options[:node_index]).to eq(2)
    end

    it 'parses node-total option' do
      options = described_class.parse_options(['--node-total', '4'])
      expect(options[:total_nodes]).to eq(4)
    end

    it 'parses xml-path option' do
      options = described_class.parse_options(['--xml-path', 'test.xml'])
      expect(options[:xml_path]).to eq('test.xml')
    end

    it 'parses debug flag' do
      options = described_class.parse_options(['--debug'])
      expect(options[:debug]).to be true
    end

    it 'sets default values' do
      options = described_class.parse_options([])
      expect(options[:node_index]).to eq(0)
      expect(options[:total_nodes]).to eq(1)
      expect(options[:debug]).to be false
    end
  end

  describe '.print_debug_info' do
    it 'outputs debug information to stderr' do
      nodes = [
        { files: ['spec/a_spec.rb', 'spec/b_spec.rb'], total_time: 5.5 },
        { files: ['spec/c_spec.rb'], total_time: 3.2 }
      ]

      output = capture_stderr do
        described_class.print_debug_info(nodes)
      end

      expect(output).to match(/Test Distribution/)
      expect(output).to match(/Node 0: 2 files, 5\.5s total/)
      expect(output).to match(/Node 1: 1 files, 3\.2s total/)
    end
  end

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end

  def capture_stderr
    original_stderr = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original_stderr
  end
end
