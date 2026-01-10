require 'nokogiri'
require 'tmpdir'
require 'fileutils'

RSpec.describe 'bin/merge-junit-xml' do
  let(:merger_script) { File.expand_path('../../bin/merge-junit-xml', __dir__) }

  around do |example|
    Dir.mktmpdir do |dir|
      @tmpdir = dir
      example.run
    end
  end

  it 'merges multiple JUnit XML files correctly' do
    # Create test XML files
    xml1 = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <testsuites>
        <testsuite name="rspec" tests="2" failures="0" errors="0" skipped="0" time="5.5">
          <testcase classname="spec.file1" name="test1" file="spec/file1_spec.rb" time="3.0"/>
          <testcase classname="spec.file1" name="test2" file="spec/file1_spec.rb" time="2.5"/>
        </testsuite>
      </testsuites>
    XML

    xml2 = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <testsuites>
        <testsuite name="rspec" tests="3" failures="0" errors="0" skipped="0" time="7.2">
          <testcase classname="spec.file2" name="test3" file="spec/file2_spec.rb" time="2.1"/>
          <testcase classname="spec.file2" name="test4" file="spec/file2_spec.rb" time="3.5"/>
          <testcase classname="spec.file2" name="test5" file="spec/file2_spec.rb" time="1.6"/>
        </testsuite>
      </testsuites>
    XML

    xml3 = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <testsuites>
        <testsuite name="rspec" tests="1" failures="0" errors="0" skipped="0" time="9.0">
          <testcase classname="spec.file3" name="test6" file="spec/file3_spec.rb" time="9.0"/>
        </testsuite>
      </testsuites>
    XML

    # Write test files
    input1 = File.join(@tmpdir, 'input1.xml')
    input2 = File.join(@tmpdir, 'input2.xml')
    input3 = File.join(@tmpdir, 'input3.xml')
    output = File.join(@tmpdir, 'output.xml')

    File.write(input1, xml1)
    File.write(input2, xml2)
    File.write(input3, xml3)

    # Run merger
    result = system(merger_script, output, input1, input2, input3)
    expect(result).to be true

    # Parse output
    doc = File.open(output) { |f| Nokogiri::XML(f) }

    # Verify structure
    expect(doc.xpath('//testsuites').size).to eq(1)
    expect(doc.xpath('//testsuite').size).to eq(3)
    expect(doc.xpath('//testcase').size).to eq(6)

    # Verify root stats
    root = doc.at('testsuites')
    expect(root['tests'].to_i).to eq(6)
    expect(root['time'].to_f).to be_within(0.1).of(21.7)

    # Verify all test cases are present
    files = doc.xpath('//testcase').map { |tc| tc['file'] }
    expect(files).to contain_exactly(
      'spec/file1_spec.rb',
      'spec/file1_spec.rb',
      'spec/file2_spec.rb',
      'spec/file2_spec.rb',
      'spec/file2_spec.rb',
      'spec/file3_spec.rb'
    )

    # Verify timings are preserved
    timings = doc.xpath('//testcase').map { |tc| tc['time'].to_f }
    expect(timings.sum).to be_within(0.1).of(21.7)
  end

  it 'handles empty input gracefully' do
    output = File.join(@tmpdir, 'output.xml')

    # Run merger with no input files
    result = system(merger_script, output, err: File::NULL)
    expect(result).to be false
  end

  it 'skips missing files with warning' do
    xml1 = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <testsuites>
        <testsuite name="rspec" tests="1" failures="0" errors="0" skipped="0" time="1.0">
          <testcase classname="spec.file1" name="test1" file="spec/file1_spec.rb" time="1.0"/>
        </testsuite>
      </testsuites>
    XML

    input1 = File.join(@tmpdir, 'input1.xml')
    missing = File.join(@tmpdir, 'missing.xml')
    output = File.join(@tmpdir, 'output.xml')

    File.write(input1, xml1)

    # Run merger with one valid and one missing file
    result = system(merger_script, output, input1, missing, err: File::NULL)
    expect(result).to be true

    # Should still create valid output
    doc = File.open(output) { |f| Nokogiri::XML(f) }
    expect(doc.xpath('//testcase').size).to eq(1)
  end
end
