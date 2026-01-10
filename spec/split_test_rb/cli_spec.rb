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
      end.to output(/Error: Either --xml-path or --xml-dir is required/).to_stderr
    end

    it 'exits with error when both xml-path and xml-dir are specified' do
      argv = ['--xml-path', fixture_path, '--xml-dir', 'tmp/results']

      expect do
        expect { described_class.run(argv) }.to raise_error(SystemExit)
      end.to output(/Error: Cannot specify both --xml-path and --xml-dir/).to_stderr
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

    it 'exits with status 0 when no test files found' do
      Tempfile.create(['empty_dir', '.xml']) do |file|
        file.write('<?xml version="1.0"?><testsuites></testsuites>')
        file.rewind

        # Temporarily change directory to a location without spec files
        Dir.mktmpdir do |tmpdir|
          Dir.chdir(tmpdir) do
            argv = ['--xml-path', file.path, '--node-index', '0', '--node-total', '1']

            expect do
              expect { described_class.run(argv) }.to raise_error(SystemExit) { |error|
                expect(error.status).to eq(0)
              }
            end.to output(/Warning: No test files found/).to_stderr
          end
        end
      end
    end

    it 'outputs debug information when --debug flag is set' do
      argv = ['--xml-path', fixture_path, '--node-index', '0', '--node-total', '2', '--debug']

      stderr_output = capture_stderr do
        capture_stdout do
          described_class.run(argv)
        end
      end

      expect(stderr_output).to match(/Test Distribution/)
      expect(stderr_output).to match(/Node 0:/)
      expect(stderr_output).to match(/Node 1:/)
    end

    it 'does not output debug information without --debug flag' do
      argv = ['--xml-path', fixture_path, '--node-index', '0', '--node-total', '2']

      stderr_output = capture_stderr do
        capture_stdout do
          described_class.run(argv)
        end
      end

      expect(stderr_output).not_to match(/Test Distribution/)
    end

    it 'does not warn when all spec files are in XML' do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          # Create spec directory and files
          FileUtils.mkdir_p('spec')
          File.write('spec/test1_spec.rb', '# test 1')
          File.write('spec/test2_spec.rb', '# test 2')

          # Create XML containing all spec files
          xml_path = 'test.xml'
          File.write(xml_path, <<~XML)
            <?xml version="1.0"?>
            <testsuites>
              <testsuite>
                <testcase file="spec/test1_spec.rb" time="1.0"/>
                <testcase file="spec/test2_spec.rb" time="2.0"/>
              </testsuite>
            </testsuites>
          XML

          argv = ['--xml-path', xml_path, '--node-index', '0', '--node-total', '1']

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

    it 'merges multiple XML files when using --xml-dir' do
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          # Create spec directory and files
          FileUtils.mkdir_p('spec')
          File.write('spec/test1_spec.rb', '# test 1')
          File.write('spec/test2_spec.rb', '# test 2')
          File.write('spec/test3_spec.rb', '# test 3')

          # Create XML directory with multiple files
          xml_dir = 'tmp/results'
          FileUtils.mkdir_p(xml_dir)

          File.write("#{xml_dir}/results-0.xml", <<~XML)
            <?xml version="1.0"?>
            <testsuites>
              <testsuite>
                <testcase file="spec/test1_spec.rb" time="5.0"/>
              </testsuite>
            </testsuites>
          XML

          File.write("#{xml_dir}/results-1.xml", <<~XML)
            <?xml version="1.0"?>
            <testsuites>
              <testsuite>
                <testcase file="spec/test2_spec.rb" time="3.0"/>
              </testsuite>
            </testsuites>
          XML

          File.write("#{xml_dir}/results-2.xml", <<~XML)
            <?xml version="1.0"?>
            <testsuites>
              <testsuite>
                <testcase file="spec/test3_spec.rb" time="2.0"/>
              </testsuite>
            </testsuites>
          XML

          argv = ['--xml-dir', xml_dir, '--node-index', '0', '--node-total', '2', '--debug']

          stderr_output = capture_stderr do
            capture_stdout do
              described_class.run(argv)
            end
          end

          # Should not warn about missing files since all are in XMLs
          expect(stderr_output).not_to match(/spec files not in XML/)
          # Should show merged timing data
          expect(stderr_output).to match(/Test Distribution/)
        end
      end
    end

    it 'falls back to all spec files when XML directory does not exist' do
      argv = ['--xml-dir', 'nonexistent_dir', '--node-index', '0', '--node-total', '1']

      stdout_output = capture_stdout do
        capture_stderr do
          described_class.run(argv)
        end
      end

      # Should output spec files from the current project
      expect(stdout_output).to match(/spec\//)
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

    it 'parses xml-dir option' do
      options = described_class.parse_options(['--xml-dir', 'tmp/results'])
      expect(options[:xml_dir]).to eq('tmp/results')
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
      timings = {
        'spec/a_spec.rb' => 3.0,
        'spec/b_spec.rb' => 2.5,
        'spec/c_spec.rb' => 3.2
      }
      default_files = Set.new

      output = capture_stderr do
        described_class.print_debug_info(nodes, timings, default_files)
      end

      expect(output).to match(/Test Distribution/)
      expect(output).to match(/Node 0: 2 files, 5\.5s total/)
      expect(output).to match(/Node 1: 1 files, 3\.2s total/)
      expect(output).to match(/spec\/a_spec\.rb \(3\.0s\)/)
      expect(output).to match(/spec\/b_spec\.rb \(2\.5s\)/)
      expect(output).to match(/spec\/c_spec\.rb \(3\.2s\)/)
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

      expect(output).to match(/spec\/a_spec\.rb \(1\.0s\)/)
      expect(output).to match(/spec\/b_spec\.rb \(1\.0s, default\)/)
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
