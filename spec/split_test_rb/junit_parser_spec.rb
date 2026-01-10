require 'spec_helper'

RSpec.describe SplitTestRb::JunitParser do
  describe '.parse' do
    let(:fixture_path) { File.expand_path('../fixtures/sample_junit.xml', __dir__) }

    it 'parses JUnit XML and extracts file timings' do
      timings = described_class.parse(fixture_path)

      expect(timings).to be_a(Hash)
      expect(timings.keys).to contain_exactly(
        'spec/models/user_spec.rb',
        'spec/models/post_spec.rb',
        'spec/controllers/users_controller_spec.rb',
        'spec/controllers/posts_controller_spec.rb',
        'spec/services/auth_service_spec.rb',
        'spec/helpers/application_helper_spec.rb'
      )
    end

    it 'aggregates timings for files with multiple test cases' do
      timings = described_class.parse(fixture_path)

      # user_spec.rb has 2 test cases: 2.5s + 1.8s = 4.3s
      expect(timings['spec/models/user_spec.rb']).to be_within(0.001).of(4.3)

      # post_spec.rb has 2 test cases: 3.2s + 2.1s = 5.3s
      expect(timings['spec/models/post_spec.rb']).to be_within(0.001).of(5.3)

      # application_helper_spec.rb has 2 test cases: 0.5s + 0.5s = 1.0s
      expect(timings['spec/helpers/application_helper_spec.rb']).to be_within(0.001).of(1.0)
    end

    it 'handles files with single test case' do
      timings = described_class.parse(fixture_path)

      expect(timings['spec/services/auth_service_spec.rb']).to eq(0.7)
    end

    context 'with empty XML' do
      it 'returns empty hash' do
        Tempfile.create(['empty', '.xml']) do |file|
          file.write('<?xml version="1.0"?><testsuites></testsuites>')
          file.rewind

          timings = described_class.parse(file.path)
          expect(timings).to eq({})
        end
      end
    end

    context 'with XML using filepath attribute' do
      it 'parses filepath attribute as well as file attribute' do
        Tempfile.create(['filepath', '.xml']) do |file|
          file.write(<<~XML)
            <?xml version="1.0"?>
            <testsuites>
              <testsuite>
                <testcase filepath="spec/example_spec.rb" time="1.5"/>
              </testsuite>
            </testsuites>
          XML
          file.rewind

          timings = described_class.parse(file.path)
          expect(timings['spec/example_spec.rb']).to eq(1.5)
        end
      end
    end

    context 'with testcase missing file path attributes' do
      it 'skips testcases without file or filepath attribute' do
        Tempfile.create(['no_filepath', '.xml']) do |file|
          file.write(<<~XML)
            <?xml version="1.0"?>
            <testsuites>
              <testsuite>
                <testcase name="some test" time="1.5"/>
                <testcase file="spec/valid_spec.rb" time="2.0"/>
              </testsuite>
            </testsuites>
          XML
          file.rewind

          timings = described_class.parse(file.path)
          expect(timings.keys).to contain_exactly('spec/valid_spec.rb')
          expect(timings['spec/valid_spec.rb']).to eq(2.0)
        end
      end
    end

    context 'with paths starting with ./' do
      it 'normalizes paths by removing leading ./' do
        Tempfile.create(['dotslash', '.xml']) do |file|
          file.write(<<~XML)
            <?xml version="1.0"?>
            <testsuites>
              <testsuite>
                <testcase file="./spec/example1_spec.rb" time="1.0"/>
                <testcase file="spec/example2_spec.rb" time="2.0"/>
                <testcase file="./spec/example3_spec.rb" time="3.0"/>
              </testsuite>
            </testsuites>
          XML
          file.rewind

          timings = described_class.parse(file.path)
          # All paths should be normalized without ./
          expect(timings.keys).to contain_exactly(
            'spec/example1_spec.rb',
            'spec/example2_spec.rb',
            'spec/example3_spec.rb'
          )
          expect(timings['spec/example1_spec.rb']).to eq(1.0)
          expect(timings['spec/example2_spec.rb']).to eq(2.0)
          expect(timings['spec/example3_spec.rb']).to eq(3.0)
        end
      end
    end
  end

  describe '.parse_files' do
    it 'parses multiple XML files and merges results' do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, 'result1.xml')
        file2 = File.join(dir, 'result2.xml')

        File.write(file1, <<~XML)
          <?xml version="1.0"?>
          <testsuites>
            <testsuite>
              <testcase file="spec/a_spec.rb" time="1.0"/>
              <testcase file="spec/b_spec.rb" time="2.0"/>
            </testsuite>
          </testsuites>
        XML

        File.write(file2, <<~XML)
          <?xml version="1.0"?>
          <testsuites>
            <testsuite>
              <testcase file="spec/c_spec.rb" time="3.0"/>
              <testcase file="spec/a_spec.rb" time="0.5"/>
            </testsuite>
          </testsuites>
        XML

        timings = described_class.parse_files([file1, file2])

        expect(timings.keys).to contain_exactly('spec/a_spec.rb', 'spec/b_spec.rb', 'spec/c_spec.rb')
        expect(timings['spec/a_spec.rb']).to be_within(0.001).of(1.5) # 1.0 + 0.5
        expect(timings['spec/b_spec.rb']).to eq(2.0)
        expect(timings['spec/c_spec.rb']).to eq(3.0)
      end
    end

    it 'skips non-existent files' do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, 'result1.xml')
        non_existent = File.join(dir, 'non_existent.xml')

        File.write(file1, <<~XML)
          <?xml version="1.0"?>
          <testsuites>
            <testsuite>
              <testcase file="spec/a_spec.rb" time="1.0"/>
            </testsuite>
          </testsuites>
        XML

        timings = described_class.parse_files([file1, non_existent])

        expect(timings.keys).to contain_exactly('spec/a_spec.rb')
        expect(timings['spec/a_spec.rb']).to eq(1.0)
      end
    end

    it 'returns empty hash for empty array' do
      timings = described_class.parse_files([])
      expect(timings).to eq({})
    end
  end

  describe '.parse_directory' do
    it 'parses all XML files in a directory' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'result1.xml'), <<~XML)
          <?xml version="1.0"?>
          <testsuites>
            <testsuite>
              <testcase file="spec/a_spec.rb" time="1.0"/>
            </testsuite>
          </testsuites>
        XML

        File.write(File.join(dir, 'result2.xml'), <<~XML)
          <?xml version="1.0"?>
          <testsuites>
            <testsuite>
              <testcase file="spec/b_spec.rb" time="2.0"/>
            </testsuite>
          </testsuites>
        XML

        timings = described_class.parse_directory(dir)

        expect(timings.keys).to contain_exactly('spec/a_spec.rb', 'spec/b_spec.rb')
        expect(timings['spec/a_spec.rb']).to eq(1.0)
        expect(timings['spec/b_spec.rb']).to eq(2.0)
      end
    end

    it 'parses XML files in subdirectories' do
      Dir.mktmpdir do |dir|
        subdir = File.join(dir, 'subdir')
        FileUtils.mkdir_p(subdir)

        File.write(File.join(dir, 'result1.xml'), <<~XML)
          <?xml version="1.0"?>
          <testsuites>
            <testsuite>
              <testcase file="spec/a_spec.rb" time="1.0"/>
            </testsuite>
          </testsuites>
        XML

        File.write(File.join(subdir, 'result2.xml'), <<~XML)
          <?xml version="1.0"?>
          <testsuites>
            <testsuite>
              <testcase file="spec/b_spec.rb" time="2.0"/>
            </testsuite>
          </testsuites>
        XML

        timings = described_class.parse_directory(dir)

        expect(timings.keys).to contain_exactly('spec/a_spec.rb', 'spec/b_spec.rb')
      end
    end

    it 'returns empty hash for empty directory' do
      Dir.mktmpdir do |dir|
        timings = described_class.parse_directory(dir)
        expect(timings).to eq({})
      end
    end
  end

  describe '.parse_path' do
    it 'parses single file when given file path' do
      Tempfile.create(['single', '.xml']) do |file|
        file.write(<<~XML)
          <?xml version="1.0"?>
          <testsuites>
            <testsuite>
              <testcase file="spec/a_spec.rb" time="1.0"/>
            </testsuite>
          </testsuites>
        XML
        file.rewind

        timings = described_class.parse_path(file.path)

        expect(timings.keys).to contain_exactly('spec/a_spec.rb')
        expect(timings['spec/a_spec.rb']).to eq(1.0)
      end
    end

    it 'parses directory when given directory path' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'result.xml'), <<~XML)
          <?xml version="1.0"?>
          <testsuites>
            <testsuite>
              <testcase file="spec/a_spec.rb" time="1.0"/>
            </testsuite>
          </testsuites>
        XML

        timings = described_class.parse_path(dir)

        expect(timings.keys).to contain_exactly('spec/a_spec.rb')
        expect(timings['spec/a_spec.rb']).to eq(1.0)
      end
    end
  end

  describe '.normalize_path' do
    it 'removes leading ./ from paths' do
      expect(described_class.normalize_path('./spec/models/user_spec.rb')).to eq('spec/models/user_spec.rb')
      expect(described_class.normalize_path('./spec/example_spec.rb')).to eq('spec/example_spec.rb')
    end

    it 'leaves paths without ./ unchanged' do
      expect(described_class.normalize_path('spec/models/user_spec.rb')).to eq('spec/models/user_spec.rb')
      expect(described_class.normalize_path('spec/example_spec.rb')).to eq('spec/example_spec.rb')
    end

    it 'handles paths with ./ in the middle' do
      expect(described_class.normalize_path('spec/./models/user_spec.rb')).to eq('spec/./models/user_spec.rb')
    end
  end
end
