# split-test-rb

A simple Ruby CLI tool to balance RSpec tests across parallel CI nodes using JUnit XML reports.

## Overview

split-test-rb reads JUnit XML test reports containing execution times and distributes test files across multiple nodes for parallel execution. It uses a greedy algorithm to ensure balanced distribution based on historical test execution times.

## Installation

```bash
gem install split-test-rb
```

Or add to your Gemfile:

```ruby
gem 'split-test-rb'
```

## Usage

### Basic Usage

```bash
split-test-rb --xml-path rspec-results.xml --node-index 0 --node-total 4
```

### Options

- `--xml-path PATH` - Path to JUnit XML report (required)
- `--node-index INDEX` - Current node index, 0-based (default: 0)
- `--node-total TOTAL` - Total number of nodes (default: 1)
- `--debug` - Show debug information with distribution details
- `-h, --help` - Show help message

### Example with RSpec

```bash
# Run tests for node 0 out of 4 total nodes
bundle exec rspec $(split-test-rb --xml-path rspec-results.xml --node-index 0 --node-total 4)
```

### Debug Mode

Use `--debug` to see how tests are distributed:

```bash
split-test-rb --xml-path rspec-results.xml --node-total 4 --debug
```

Output:
```
=== Test Distribution ===
Node 0: 5 files, 12.34s total
  - spec/models/user_spec.rb
  - spec/controllers/users_controller_spec.rb
  ...
Node 1: 6 files, 12.45s total
  - spec/models/post_spec.rb
  ...
=========================
```

## GitHub Actions Example

```yaml
name: RSpec

on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node_index: [0, 1, 2, 3]
    steps:
      - uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Download previous test results
        uses: actions/download-artifact@v4
        with:
          name: rspec-results
          path: tmp/
        continue-on-error: true

      - name: Run tests
        run: |
          bundle exec rspec \
            --format progress \
            --format RspecJunitFormatter \
            --out tmp/rspec-results.xml \
            $(bundle exec split-test-rb \
              --xml-path tmp/rspec-results.xml \
              --node-index ${{ matrix.node_index }} \
              --node-total 4)

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: rspec-results
          path: tmp/rspec-results.xml
```

## How It Works

1. **Parse JUnit XML**: Extracts test file paths and execution times from the XML report
2. **Greedy Balancing**: Sorts files by execution time (descending) and assigns each file to the node with the lowest cumulative time
3. **Output**: Prints the list of test files for the specified node

## JUnit XML Format

The tool expects JUnit XML with `file` or `filepath` attributes on testcase elements:

```xml
<testsuite>
  <testcase file="spec/models/user_spec.rb" time="1.234" />
  <testcase file="spec/models/post_spec.rb" time="0.567" />
</testsuite>
```

For RSpec, use the `rspec_junit_formatter` gem to generate compatible XML reports.

## License

MIT