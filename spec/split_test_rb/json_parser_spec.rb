require 'spec_helper'

RSpec.describe SplitTestRb::JsonParser do
  describe '.parse' do
    let(:fixture_path) { File.expand_path('../fixtures/sample_rspec.json', __dir__) }

    it 'parses RSpec JSON and extracts file timings' do
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

    context 'with empty JSON' do
      it 'returns empty hash' do
        Tempfile.create(['empty', '.json']) do |file|
          file.write('{"examples": []}')
          file.rewind

          timings = described_class.parse(file.path)
          expect(timings).to eq({})
        end
      end
    end

    context 'with JSON missing examples key' do
      it 'returns empty hash' do
        Tempfile.create(['no_examples', '.json']) do |file|
          file.write('{"summary": {}}')
          file.rewind

          timings = described_class.parse(file.path)
          expect(timings).to eq({})
        end
      end
    end

    context 'with example missing file_path' do
      it 'skips examples without file_path' do
        Tempfile.create(['no_filepath', '.json']) do |file|
          file.write(<<~JSON)
            {
              "examples": [
                {"description": "some test", "run_time": 1.5},
                {"file_path": "./spec/valid_spec.rb", "run_time": 2.0}
              ]
            }
          JSON
          file.rewind

          timings = described_class.parse(file.path)
          expect(timings.keys).to contain_exactly('spec/valid_spec.rb')
          expect(timings['spec/valid_spec.rb']).to eq(2.0)
        end
      end
    end

    context 'with paths starting with ./' do
      it 'normalizes paths by removing leading ./' do
        Tempfile.create(['dotslash', '.json']) do |file|
          file.write(<<~JSON)
            {
              "examples": [
                {"file_path": "./spec/example1_spec.rb", "run_time": 1.0},
                {"file_path": "spec/example2_spec.rb", "run_time": 2.0},
                {"file_path": "./spec/example3_spec.rb", "run_time": 3.0}
              ]
            }
          JSON
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
    it 'parses multiple JSON files and merges results' do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, 'result1.json')
        file2 = File.join(dir, 'result2.json')

        File.write(file1, <<~JSON)
          {
            "examples": [
              {"file_path": "./spec/a_spec.rb", "run_time": 1.0},
              {"file_path": "./spec/b_spec.rb", "run_time": 2.0}
            ]
          }
        JSON

        File.write(file2, <<~JSON)
          {
            "examples": [
              {"file_path": "./spec/c_spec.rb", "run_time": 3.0},
              {"file_path": "./spec/a_spec.rb", "run_time": 0.5}
            ]
          }
        JSON

        timings = described_class.parse_files([file1, file2])

        expect(timings.keys).to contain_exactly('spec/a_spec.rb', 'spec/b_spec.rb', 'spec/c_spec.rb')
        expect(timings['spec/a_spec.rb']).to be_within(0.001).of(1.5) # 1.0 + 0.5
        expect(timings['spec/b_spec.rb']).to eq(2.0)
        expect(timings['spec/c_spec.rb']).to eq(3.0)
      end
    end

    it 'skips non-existent files' do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, 'result1.json')
        non_existent = File.join(dir, 'non_existent.json')

        File.write(file1, <<~JSON)
          {
            "examples": [
              {"file_path": "./spec/a_spec.rb", "run_time": 1.0}
            ]
          }
        JSON

        timings = described_class.parse_files([file1, non_existent])

        expect(timings.keys).to contain_exactly('spec/a_spec.rb')
        expect(timings['spec/a_spec.rb']).to eq(1.0)
      end
    end

    it 'returns empty hash for empty array' do
      timings = described_class.parse_files([])
      expect(timings).to eq({})
    end

    it 'skips empty files' do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, 'result1.json')
        empty_file = File.join(dir, 'empty.json')

        File.write(file1, <<~JSON)
          {
            "examples": [
              {"file_path": "./spec/a_spec.rb", "run_time": 1.0}
            ]
          }
        JSON

        File.write(empty_file, '')

        timings = described_class.parse_files([file1, empty_file])

        expect(timings.keys).to contain_exactly('spec/a_spec.rb')
        expect(timings['spec/a_spec.rb']).to eq(1.0)
      end
    end

    it 'skips files with invalid JSON and outputs warning' do
      Dir.mktmpdir do |dir|
        file1 = File.join(dir, 'result1.json')
        invalid_file = File.join(dir, 'invalid.json')

        File.write(file1, <<~JSON)
          {
            "examples": [
              {"file_path": "./spec/a_spec.rb", "run_time": 1.0}
            ]
          }
        JSON

        File.write(invalid_file, 'invalid json content')

        expect do
          timings = described_class.parse_files([file1, invalid_file])
          expect(timings.keys).to contain_exactly('spec/a_spec.rb')
          expect(timings['spec/a_spec.rb']).to eq(1.0)
        end.to output(/Warning: Failed to parse.*invalid\.json/).to_stderr
      end
    end
  end

  describe '.parse_directory' do
    it 'parses all JSON files in a directory' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'result1.json'), <<~JSON)
          {
            "examples": [
              {"file_path": "./spec/a_spec.rb", "run_time": 1.0}
            ]
          }
        JSON

        File.write(File.join(dir, 'result2.json'), <<~JSON)
          {
            "examples": [
              {"file_path": "./spec/b_spec.rb", "run_time": 2.0}
            ]
          }
        JSON

        timings = described_class.parse_directory(dir)

        expect(timings.keys).to contain_exactly('spec/a_spec.rb', 'spec/b_spec.rb')
        expect(timings['spec/a_spec.rb']).to eq(1.0)
        expect(timings['spec/b_spec.rb']).to eq(2.0)
      end
    end

    it 'parses JSON files in subdirectories' do
      Dir.mktmpdir do |dir|
        subdir = File.join(dir, 'subdir')
        FileUtils.mkdir_p(subdir)

        File.write(File.join(dir, 'result1.json'), <<~JSON)
          {
            "examples": [
              {"file_path": "./spec/a_spec.rb", "run_time": 1.0}
            ]
          }
        JSON

        File.write(File.join(subdir, 'result2.json'), <<~JSON)
          {
            "examples": [
              {"file_path": "./spec/b_spec.rb", "run_time": 2.0}
            ]
          }
        JSON

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
