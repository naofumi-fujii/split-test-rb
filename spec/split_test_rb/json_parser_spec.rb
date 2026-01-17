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

    it 'aggregates timings for files with multiple examples' do
      timings = described_class.parse(fixture_path)

      # user_spec.rb has 2 examples: 2.5s + 1.8s = 4.3s
      expect(timings['spec/models/user_spec.rb']).to be_within(0.001).of(4.3)

      # post_spec.rb has 2 examples: 3.2s + 2.1s = 5.3s
      expect(timings['spec/models/post_spec.rb']).to be_within(0.001).of(5.3)

      # application_helper_spec.rb has 2 examples: 0.5s + 0.5s = 1.0s
      expect(timings['spec/helpers/application_helper_spec.rb']).to be_within(0.001).of(1.0)

      # users_controller_spec.rb has 2 examples: 1.5s + 0.8s = 2.3s
      expect(timings['spec/controllers/users_controller_spec.rb']).to be_within(0.001).of(2.3)
    end

    it 'handles files with single example' do
      timings = described_class.parse(fixture_path)

      expect(timings['spec/services/auth_service_spec.rb']).to eq(0.7)
      expect(timings['spec/controllers/posts_controller_spec.rb']).to eq(1.9)
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
          file.write('{"version": "3.13.0"}')
          file.rewind

          timings = described_class.parse(file.path)
          expect(timings).to eq({})
        end
      end
    end

    context 'when file paths start with ./' do
      it 'normalizes paths by removing leading ./' do
        timings = described_class.parse(fixture_path)

        # Verify all keys are normalized (no leading ./)
        timings.keys.each do |path|
          expect(path).not_to start_with('./')
        end

        # Verify we can find files by normalized paths
        expect(timings['spec/models/user_spec.rb']).to be > 0
        expect(timings['spec/models/post_spec.rb']).to be > 0
      end
    end

    context 'when examples have no file_path' do
      it 'skips those examples' do
        Tempfile.create(['no_filepath', '.json']) do |file|
          json_content = {
            examples: [
              { description: 'test 1', run_time: 1.0 },
              { description: 'test 2', file_path: 'spec/test_spec.rb', run_time: 2.0 }
            ]
          }.to_json

          file.write(json_content)
          file.rewind

          timings = described_class.parse(file.path)
          expect(timings).to eq('spec/test_spec.rb' => 2.0)
        end
      end
    end
  end

  describe '.parse_directory' do
    it 'parses all JSON files in directory' do
      Dir.mktmpdir do |tmpdir|
        # Create multiple JSON files
        File.write(
          File.join(tmpdir, 'rspec1.json'),
          { examples: [{ file_path: 'spec/a_spec.rb', run_time: 1.0 }] }.to_json
        )
        File.write(
          File.join(tmpdir, 'rspec2.json'),
          { examples: [{ file_path: 'spec/b_spec.rb', run_time: 2.0 }] }.to_json
        )

        timings = described_class.parse_directory(tmpdir)

        expect(timings).to eq(
          'spec/a_spec.rb' => 1.0,
          'spec/b_spec.rb' => 2.0
        )
      end
    end

    it 'merges timings from multiple files for the same spec' do
      Dir.mktmpdir do |tmpdir|
        # Both JSON files reference the same spec file
        File.write(
          File.join(tmpdir, 'rspec1.json'),
          { examples: [{ file_path: 'spec/a_spec.rb', run_time: 1.0 }] }.to_json
        )
        File.write(
          File.join(tmpdir, 'rspec2.json'),
          { examples: [{ file_path: 'spec/a_spec.rb', run_time: 2.0 }] }.to_json
        )

        timings = described_class.parse_directory(tmpdir)

        # Timings should be merged: 1.0 + 2.0 = 3.0
        expect(timings).to eq('spec/a_spec.rb' => 3.0)
      end
    end

    it 'parses JSON files in subdirectories' do
      Dir.mktmpdir do |tmpdir|
        subdir = File.join(tmpdir, 'results')
        FileUtils.mkdir_p(subdir)

        File.write(
          File.join(subdir, 'rspec.json'),
          { examples: [{ file_path: 'spec/a_spec.rb', run_time: 1.5 }] }.to_json
        )

        timings = described_class.parse_directory(tmpdir)

        expect(timings).to eq('spec/a_spec.rb' => 1.5)
      end
    end
  end

  describe '.parse_files' do
    it 'parses multiple JSON files' do
      files = []
      Dir.mktmpdir do |tmpdir|
        file1 = File.join(tmpdir, 'rspec1.json')
        file2 = File.join(tmpdir, 'rspec2.json')

        File.write(
          file1,
          { examples: [{ file_path: 'spec/a_spec.rb', run_time: 1.0 }] }.to_json
        )
        File.write(
          file2,
          { examples: [{ file_path: 'spec/b_spec.rb', run_time: 2.0 }] }.to_json
        )

        files = [file1, file2]
        timings = described_class.parse_files(files)

        expect(timings).to eq(
          'spec/a_spec.rb' => 1.0,
          'spec/b_spec.rb' => 2.0
        )
      end
    end

    it 'skips non-existent files' do
      Dir.mktmpdir do |tmpdir|
        existing_file = File.join(tmpdir, 'rspec.json')
        non_existent_file = File.join(tmpdir, 'does_not_exist.json')

        File.write(
          existing_file,
          { examples: [{ file_path: 'spec/a_spec.rb', run_time: 1.0 }] }.to_json
        )

        timings = described_class.parse_files([existing_file, non_existent_file])

        expect(timings).to eq('spec/a_spec.rb' => 1.0)
      end
    end
  end

  describe '.normalize_path' do
    it 'removes leading ./ from path' do
      expect(described_class.normalize_path('./spec/models/user_spec.rb')).to eq('spec/models/user_spec.rb')
    end

    it 'leaves path unchanged if no leading ./' do
      expect(described_class.normalize_path('spec/models/user_spec.rb')).to eq('spec/models/user_spec.rb')
    end

    it 'only removes leading ./ not internal ones' do
      expect(described_class.normalize_path('./spec/./models/user_spec.rb')).to eq('spec/./models/user_spec.rb')
    end
  end
end
