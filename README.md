# split-test-rb

A simple Ruby CLI tool to balance RSpec tests across parallel CI nodes using JUnit XML reports.

## Overview

split-test-rb reads JUnit XML test reports containing execution times and distributes test files across multiple nodes for parallel execution. It uses a greedy algorithm to ensure balanced distribution based on historical test execution times.

## Installation

Since this gem is not yet published to RubyGems, you need to install it from GitHub.

Add to your Gemfile:

```ruby
gem 'split-test-rb', github: 'naofumi-fujii/split-test-rb'
```

Then run:

```bash
bundle install
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

First, add split-test-rb to your Gemfile:

```ruby
# Gemfile
gem 'split-test-rb', github: 'naofumi-fujii/split-test-rb'
```

- [.github/workflows/ci.yml](https://github.com/naofumi-fujii/split-test-rb/blob/main/.github/workflows/ci.yml)

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

## Development

### Running Tests

This repository includes RSpec tests that demonstrate how the tool works:

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/split_test_rb/balancer_spec.rb
```

Tests automatically generate a JUnit XML report at `tmp/rspec-results.xml`.

### Testing the Tool with Its Own Tests

You can use split-test-rb to distribute its own test suite:

```bash
# First, run tests to generate the JUnit XML report
bundle exec rspec

# View how tests would be distributed across 2 nodes (debug mode)
bin/split-test-rb --xml-path tmp/rspec-results.xml --node-total 2 --debug

# Run tests for node 0 of 2
bundle exec rspec $(bin/split-test-rb --xml-path tmp/rspec-results.xml --node-index 0 --node-total 2)

# Run tests for node 1 of 2
bundle exec rspec $(bin/split-test-rb --xml-path tmp/rspec-results.xml --node-index 1 --node-total 2)
```

This demonstrates the tool's ability to balance test execution across multiple parallel nodes.

## License

MIT
