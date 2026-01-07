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
      expect(timings['spec/models/user_spec.rb']).to eq(4.3)

      # post_spec.rb has 2 test cases: 3.2s + 2.1s = 5.3s
      expect(timings['spec/models/post_spec.rb']).to eq(5.3)

      # application_helper_spec.rb has 2 test cases: 0.5s + 0.5s = 1.0s
      expect(timings['spec/helpers/application_helper_spec.rb']).to eq(1.0)
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
  end
end
