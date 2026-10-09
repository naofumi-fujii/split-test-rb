require 'spec_helper'

RSpec.describe SplitTestRb::DryRunner do
  def with_temp_test_dir(&)
    Dir.mktmpdir { |tmpdir| Dir.chdir(tmpdir, &) }
  end

  # Writes a stand-in for rspec that records its arguments and writes the dry-run JSON to --out
  def write_fake_rspec(examples_json)
    File.write('fake_rspec.rb', <<~RUBY)
      File.write('args.txt', ARGV.join(' '))
      puts 'noise on stdout'
      File.write(ARGV[ARGV.index('--out') + 1], '#{examples_json}')
    RUBY
  end

  it 'returns the example IDs from the dry-run JSON' do
    with_temp_test_dir do
      write_fake_rspec('{"examples": [{"id": "./spec/a_spec.rb[1:1]"}, {"id": "./spec/a_spec.rb[1:2]"}]}')

      result = described_class.new('ruby fake_rspec.rb').example_ids(['spec/a_spec.rb'])

      expect(result).to eq(['spec/a_spec.rb[1:1]', 'spec/a_spec.rb[1:2]'])
    end
  end

  it 'runs rspec with --dry-run, --order defined and the given files' do
    with_temp_test_dir do
      write_fake_rspec('{"examples": []}')

      described_class.new('ruby fake_rspec.rb').example_ids(['spec/a_spec.rb', 'spec/b_spec.rb'])

      expect(File.read('args.txt')).to match(
        %r{\A--dry-run --order defined --format json --out \S+ spec/a_spec.rb spec/b_spec.rb\z}
      )
    end
  end

  it 'does not write the output of rspec to stdout' do
    with_temp_test_dir do
      write_fake_rspec('{"examples": []}')

      expect { described_class.new('ruby fake_rspec.rb').example_ids(['spec/a_spec.rb']) }.not_to output.to_stdout
    end
  end

  it 'returns nil with a warning when rspec exits with a non-zero status' do
    with_temp_test_dir do
      File.write('fake_rspec.rb', "warn 'load error'\nexit 1")

      expect do
        expect(described_class.new('ruby fake_rspec.rb').example_ids(['spec/a_spec.rb'])).to be_nil
      end.to output(/Warning: rspec dry-run failed.*exited with status 1\nload error/m).to_stderr
    end
  end

  it 'returns nil with a warning when the command is not found' do
    expect do
      expect(described_class.new('split-test-rb-missing-command').example_ids(['spec/a_spec.rb'])).to be_nil
    end.to output(/Warning: rspec dry-run failed/).to_stderr
  end

  it 'returns nil with a warning when the JSON is not written' do
    with_temp_test_dir do
      File.write('fake_rspec.rb', '')

      expect do
        expect(described_class.new('ruby fake_rspec.rb').example_ids(['spec/a_spec.rb'])).to be_nil
      end.to output(/Warning: rspec dry-run failed/).to_stderr
    end
  end

  it 'returns nil with a warning when the JSON is invalid' do
    with_temp_test_dir do
      write_fake_rspec('not json')

      expect do
        expect(described_class.new('ruby fake_rspec.rb').example_ids(['spec/a_spec.rb'])).to be_nil
      end.to output(/Warning: rspec dry-run failed/).to_stderr
    end
  end
end
