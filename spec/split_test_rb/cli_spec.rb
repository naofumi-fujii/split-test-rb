require 'spec_helper'

RSpec.describe SplitTestRb::CLI do
  let(:fixture_dir) { File.expand_path('../fixtures', __dir__) }

  describe '.run' do
    it 'outputs files for specified node' do
      argv = ['--xml-path', fixture_dir, '--node-index', '0', '--node-total', '2']

      expect do
        described_class.run(argv)
      end.to output(%r{spec/}).to_stdout
    end

    it 'exits with error when xml-path is missing' do
      argv = []

      expect do
        expect { described_class.run(argv) }.to raise_error(SystemExit)
      end.to output(/Error: --xml-path is required/).to_stderr
    end

    it 'falls back to all spec files when XML directory does not exist' do
      argv = ['--xml-path', 'nonexistent_dir', '--node-index', '0', '--node-total', '1']

      stdout_output = capture_stdout do
        capture_stderr do
          described_class.run(argv)
        end
      end

      # Should output spec files from the current project
      expect(stdout_output).to match(%r{spec/})
    end

    it 'outputs different files for different nodes' do
      node0_output = capture_stdout do
        described_class.run(['--xml-path', fixture_dir, '--node-index', '0', '--node-total', '2'])
      end

      node1_output = capture_stdout do
        described_class.run(['--xml-path', fixture_dir, '--node-index', '1', '--node-total', '2'])
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
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          # Create empty XML directory
          xml_dir = File.join(tmpdir, 'xml_results')
          FileUtils.mkdir_p(xml_dir)
          File.write(File.join(xml_dir, 'empty.xml'), '<?xml version="1.0"?><testsuites></testsuites>')

          argv = ['--xml-path', xml_dir, '--node-index', '0', '--node-total', '1']

          expect do
            expect { described_class.run(argv) }.to raise_error(SystemExit) { |error|
              expect(error.status).to eq(0)
            }
          end.to output(/Warning: No test files found/).to_stderr
        end
      end
    end

    it 'outputs debug information when --debug flag is set' do
      argv = ['--xml-path', fixture_dir, '--node-index', '0', '--node-total', '2', '--debug']

      stderr_output = capture_stderr do
        capture_stdout do
          described_class.run(argv)
        end
      end

      expect(stderr_output).to match(/Test Balancing/)
      expect(stderr_output).to match(/Node 0:/)
      expect(stderr_output).to match(/Node 1:/)
    end

    it 'does not output debug information without --debug flag' do
      argv = ['--xml-path', fixture_dir, '--node-index', '0', '--node-total', '2']

      stderr_output = capture_stderr do
        capture_stdout do
          described_class.run(argv)
        end
      end

      expect(stderr_output).not_to match(/Test Balancing/)
    end

    it 'does not warn when all spec files are in XML' do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          # Create spec directory and files
          FileUtils.mkdir_p('spec')
          File.write('spec/test1_spec.rb', '# test 1')
          File.write('spec/test2_spec.rb', '# test 2')

          # Create XML directory containing all spec files
          xml_dir = 'xml_results'
          FileUtils.mkdir_p(xml_dir)
          File.write(File.join(xml_dir, 'test.xml'), <<~XML)
            <?xml version="1.0"?>
            <testsuites>
              <testsuite>
                <testcase file="spec/test1_spec.rb" time="1.0"/>
                <testcase file="spec/test2_spec.rb" time="2.0"/>
              </testsuite>
            </testsuites>
          XML

          argv = ['--xml-path', xml_dir, '--node-index', '0', '--node-total', '1']

          stderr_output = capture_stderr do
            capture_stdout do
              described_class.run(argv)
            end
          end

          # Should not warn about missing files
          expect(stderr_output).not_to match(/spec files not in XML/)
        end
      end
    end

    it 'uses custom test directory when --test-dir is specified' do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          # Create test directory and files
          FileUtils.mkdir_p('test')
          File.write('test/user_test.rb', '# test 1')
          File.write('test/post_test.rb', '# test 2')

          # Create XML directory
          xml_dir = 'xml_results'
          FileUtils.mkdir_p(xml_dir)
          File.write(File.join(xml_dir, 'test.xml'), <<~XML)
            <?xml version="1.0"?>
            <testsuites>
              <testsuite>
                <testcase file="test/user_test.rb" time="1.0"/>
              </testsuite>
            </testsuites>
          XML

          argv = ['--xml-path', xml_dir, '--node-index', '0', '--node-total', '1', '--test-dir', 'test',
                  '--test-pattern', '**/*_test.rb']

          stdout_output = capture_stdout do
            capture_stderr do
              described_class.run(argv)
            end
          end

          # Should output both test files (one from XML, one added with default time)
          expect(stdout_output).to include('test/user_test.rb')
          expect(stdout_output).to include('test/post_test.rb')
        end
      end
    end

    it 'uses custom test pattern when --test-pattern is specified' do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          # Create test directory with custom pattern
          FileUtils.mkdir_p('test/unit')
          File.write('test/unit/user.test.rb', '# test 1')
          File.write('test/unit/post.test.rb', '# test 2')

          # Create empty XML directory
          xml_dir = 'xml_results'
          FileUtils.mkdir_p(xml_dir)
          File.write(File.join(xml_dir, 'empty.xml'), '<?xml version="1.0"?><testsuites></testsuites>')

          argv = ['--xml-path', xml_dir, '--node-index', '0', '--node-total', '1', '--test-dir', 'test',
                  '--test-pattern', 'unit/*.test.rb']

          stdout_output = capture_stdout do
            capture_stderr do
              described_class.run(argv)
            end
          end

          # Should output files matching the custom pattern
          expect(stdout_output).to include('test/unit/user.test.rb')
          expect(stdout_output).to include('test/unit/post.test.rb')
        end
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

    it 'parses xml-path option' do
      options = described_class.parse_options(['--xml-path', 'test.xml'])
      expect(options[:xml_path]).to eq('test.xml')
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
    it 'outputs debug information to stderr' do
      nodes = [
        { files: ['spec/a_spec.rb', 'spec/b_spec.rb'], total_time: 5.5 },
        { files: ['spec/c_spec.rb'], total_time: 3.2 }
      ]
      timings = {
        'spec/a_spec.rb' => 3.0,
        'spec/b_spec.rb' => 2.5,
        'spec/c_spec.rb' => 3.2
      }
      default_files = Set.new

      output = capture_stderr do
        described_class.print_debug_info(nodes, timings, default_files)
      end

      expect(output).to match(/Test Balancing Debug Info/)
      expect(output).to match(/Timing Data Source \(from past test execution results\)/)
      expect(output).to match(/Files with historical timing: 3 files/)
      expect(output).to match(/Files with default timing \(1\.0s\): 0 files/)
      expect(output).to match(/Total files: 3 files/)
      expect(output).to match(/Total estimated time: 8\.7s/)
      expect(output).to match(/Load Balance/)
      expect(output).to match(/Average time per node: 4\.35s/)
      expect(output).to match(/Max deviation from average: 26\.4%/)
      expect(output).to match(/Per-Node Distribution/)
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
end
