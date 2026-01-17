require 'spec_helper'

RSpec.describe SplitTestRb::CLI do
  let(:fixture_dir) { File.expand_path('../fixtures', __dir__) }

  describe '.run' do
    it 'outputs files for specified node' do
      argv = ['--json-path', fixture_dir, '--node-index', '0', '--node-total', '2']

      expect do
        described_class.run(argv)
      end.to output(%r{spec/}).to_stdout
    end

    it 'exits with error when json-path is missing' do
      argv = []

      expect do
        expect { described_class.run(argv) }.to raise_error(SystemExit)
      end.to output(/Error: --json-path is required/).to_stderr
    end

    it 'falls back to all spec files when JSON directory does not exist' do
      argv = ['--json-path', 'nonexistent_dir', '--node-index', '0', '--node-total', '1']

      output = run_cli_capturing_both(argv)

      # Should output spec files from the current project
      expect(output[:stdout]).to match(%r{spec/})
    end

    it 'outputs different files for different nodes' do
      node0_output = capture_stdout do
        described_class.run(['--json-path', fixture_dir, '--node-index', '0', '--node-total', '2'])
      end

      node1_output = capture_stdout do
        described_class.run(['--json-path', fixture_dir, '--node-index', '1', '--node-total', '2'])
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

    it 'exits with status 0 when no test files found' do
      # Temporarily change directory to a location without spec files
      with_temp_test_dir do |tmpdir|
        # Create empty JSON directory
        json_dir = File.join(tmpdir, 'json_results')
        FileUtils.mkdir_p(json_dir)
        File.write(File.join(json_dir, 'empty.json'), '{"examples": []}')

        argv = ['--json-path', json_dir, '--node-index', '0', '--node-total', '1']

        expect do
          expect { described_class.run(argv) }.to raise_error(SystemExit) { |error|
            expect(error.status).to eq(0)
          }
        end.to output(/Warning: No test files found/).to_stderr
      end
    end

    it 'outputs debug information when --debug flag is set' do
      argv = ['--json-path', fixture_dir, '--node-index', '0', '--node-total', '2', '--debug']

      output = run_cli_capturing_both(argv)

      expect(output[:stderr]).to match(/Test Balancing/)
      expect(output[:stderr]).to match(/Node 0:/)
      expect(output[:stderr]).to match(/Node 1:/)
    end

    it 'does not output debug information without --debug flag' do
      argv = ['--json-path', fixture_dir, '--node-index', '0', '--node-total', '2']

      output = run_cli_capturing_both(argv)

      expect(output[:stderr]).not_to match(/Test Balancing/)
    end

    it 'does not warn when all spec files are in JSON' do
      with_temp_test_dir do
        # Create spec directory and files
        FileUtils.mkdir_p('spec')
        File.write('spec/test1_spec.rb', '# test 1')
        File.write('spec/test2_spec.rb', '# test 2')

        # Create JSON directory containing all spec files
        json_dir = 'json_results'
        FileUtils.mkdir_p(json_dir)
        create_json_file(File.join(json_dir, 'test.json'), [
                           { file_path: './spec/test1_spec.rb', run_time: 1.0 },
                           { file_path: './spec/test2_spec.rb', run_time: 2.0 }
                         ])

        argv = ['--json-path', json_dir, '--node-index', '0', '--node-total', '1']

        output = run_cli_capturing_both(argv)

        # Should not warn about missing files
        expect(output[:stderr]).not_to match(/spec files not in JSON/)
      end
    end

    it 'uses custom test directory when --test-dir is specified' do
      with_temp_test_dir do
        # Create test directory and files
        FileUtils.mkdir_p('test')
        File.write('test/user_test.rb', '# test 1')
        File.write('test/post_test.rb', '# test 2')

        # Create JSON directory
        json_dir = 'json_results'
        FileUtils.mkdir_p(json_dir)
        create_json_file(File.join(json_dir, 'test.json'), [
                           { file_path: './test/user_test.rb', run_time: 1.0 }
                         ])

        argv = ['--json-path', json_dir, '--node-index', '0', '--node-total', '1', '--test-dir', 'test',
                '--test-pattern', '**/*_test.rb']

        output = run_cli_capturing_both(argv)

        # Should output both test files (one from JSON, one added with default time)
        expect(output[:stdout]).to include('test/user_test.rb')
        expect(output[:stdout]).to include('test/post_test.rb')
      end
    end

    it 'uses custom test pattern when --test-pattern is specified' do
      with_temp_test_dir do
        # Create test directory with custom pattern
        FileUtils.mkdir_p('test/unit')
        File.write('test/unit/user.test.rb', '# test 1')
        File.write('test/unit/post.test.rb', '# test 2')

        # Create empty JSON directory
        json_dir = 'json_results'
        FileUtils.mkdir_p(json_dir)
        File.write(File.join(json_dir, 'empty.json'), '{"examples": []}')

        argv = ['--json-path', json_dir, '--node-index', '0', '--node-total', '1', '--test-dir', 'test',
                '--test-pattern', 'unit/*.test.rb']

        output = run_cli_capturing_both(argv)

        # Should output files matching the custom pattern
        expect(output[:stdout]).to include('test/unit/user.test.rb')
        expect(output[:stdout]).to include('test/unit/post.test.rb')
      end
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

    it 'parses json-path option' do
      options = described_class.parse_options(['--json-path', 'test.json'])
      expect(options[:json_path]).to eq('test.json')
    end

    it 'parses debug flag' do
      options = described_class.parse_options(['--debug'])
      expect(options[:debug]).to be true
    end

    it 'parses test-dir option' do
      options = described_class.parse_options(['--test-dir', 'test'])
      expect(options[:test_dir]).to eq('test')
    end

    it 'parses test-pattern option' do
      options = described_class.parse_options(['--test-pattern', '**/*_test.rb'])
      expect(options[:test_pattern]).to eq('**/*_test.rb')
    end

    it 'sets default values' do
      options = described_class.parse_options([])
      expect(options[:node_index]).to eq(0)
      expect(options[:total_nodes]).to eq(1)
      expect(options[:debug]).to be false
      expect(options[:test_dir]).to eq('spec')
      expect(options[:test_pattern]).to eq('**/*_spec.rb')
    end
  end

  describe '.print_debug_info' do
    let(:nodes) do
      [
        { files: ['spec/a_spec.rb', 'spec/b_spec.rb'], total_time: 5.5 },
        { files: ['spec/c_spec.rb'], total_time: 3.2 }
      ]
    end
    let(:timings) do
      {
        'spec/a_spec.rb' => 3.0,
        'spec/b_spec.rb' => 2.5,
        'spec/c_spec.rb' => 3.2
      }
    end
    let(:default_files) { Set.new }

    it 'outputs debug sections and structure' do
      output = capture_stderr do
        described_class.print_debug_info(nodes, timings, default_files)
      end

      expect(output).to match(/Test Balancing Debug Info/)
      expect(output).to match(/Timing Data Source \(from past test execution results\)/)
      expect(output).to match(/Load Balance/)
      expect(output).to match(/Per-Node Distribution/)
    end

    it 'outputs timing data source statistics' do
      output = capture_stderr do
        described_class.print_debug_info(nodes, timings, default_files)
      end

      expect(output).to match(/Files with historical timing: 3 files/)
      expect(output).to match(/Files with default timing \(1\.0s\): 0 files/)
      expect(output).to match(/Total files: 3 files/)
      expect(output).to match(/Total estimated time: 8\.7s/)
    end

    it 'outputs load balance statistics' do
      output = capture_stderr do
        described_class.print_debug_info(nodes, timings, default_files)
      end

      expect(output).to match(/Average time per node: 4\.35s/)
      expect(output).to match(/Max deviation from average: 26\.4%/)
    end

    it 'outputs per-node distribution with deviations' do
      output = capture_stderr do
        described_class.print_debug_info(nodes, timings, default_files)
      end

      expect(output).to match(/Node 0: 2 files, 5\.5s \(\+26\.4% from avg\)/)
      expect(output).to match(/Node 1: 1 files, 3\.2s \(-26\.4% from avg\)/)
      expect(output).to match(%r{spec/a_spec\.rb \(3\.0s\)})
      expect(output).to match(%r{spec/b_spec\.rb \(2\.5s\)})
      expect(output).to match(%r{spec/c_spec\.rb \(3\.2s\)})
    end

    it 'marks default files in debug output' do
      nodes = [
        { files: ['spec/a_spec.rb', 'spec/b_spec.rb'], total_time: 2.0 }
      ]
      timings = {
        'spec/a_spec.rb' => 1.0,
        'spec/b_spec.rb' => 1.0
      }
      default_files = Set.new(['spec/b_spec.rb'])

      output = capture_stderr do
        described_class.print_debug_info(nodes, timings, default_files)
      end

      expect(output).to match(/Test Balancing Debug Info/)
      expect(output).to match(/Files with historical timing: 1 files/)
      expect(output).to match(/Files with default timing \(1\.0s\): 1 files/)
      expect(output).to match(/Total files: 2 files/)
      expect(output).to match(/Total estimated time: 2\.0s/)
      expect(output).to match(%r{spec/a_spec\.rb \(1\.0s\)})
      expect(output).to match(%r{spec/b_spec\.rb \(1\.0s, default - no historical data\)})
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

  def run_cli_capturing_both(argv)
    stdout_output = nil
    stderr_output = capture_stderr do
      stdout_output = capture_stdout do
        described_class.run(argv)
      end
    end
    { stdout: stdout_output, stderr: stderr_output }
  end

  def with_temp_test_dir
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        yield tmpdir
      end
    end
  end

  def create_json_file(path, examples)
    json_content = {
      examples: examples.map { |ex| { file_path: ex[:file_path], run_time: ex[:run_time] } }
    }
    File.write(path, JSON.generate(json_content))
  end
end
