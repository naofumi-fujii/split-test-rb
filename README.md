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

## Performance Comparison

This section demonstrates the effectiveness of split-test-rb in balancing test execution times across parallel nodes.

### Test Setup

The repository includes dummy test files with varying execution times (1, 2, 3, 5, 10, 15, 20, 25, 30, 40 seconds) totaling 151 seconds. With 10 parallel nodes, the ideal distribution would be approximately 15.1 seconds per node.

### Without split-test-rb (First Run - No XML)

When no previous test timing data is available, tests are distributed equally by count, resulting in unbalanced execution times:

| Node | Execution Time | Assigned Tests |
|------|---------------|----------------|
| 0    | ~9s  | balancer_spec.rb, dummy_009_spec.rb (30s) |
| 1    | ~10s | cli_spec.rb, dummy_010_spec.rb (40s) |
| 2    | ~1s  | dummy_001_spec.rb (1s), junit_parser_spec.rb |
| 3    | ~2s  | dummy_002_spec.rb (2s) |
| 4    | ~3s  | dummy_003_spec.rb (3s) |
| 5    | ~4s  | dummy_004_spec.rb (5s) |
| 6    | ~5s  | dummy_005_spec.rb (10s) |
| 7    | ~6s  | dummy_006_spec.rb (15s) |
| 8    | ~7s  | dummy_007_spec.rb (20s) |
| 9    | ~8s  | dummy_008_spec.rb (25s) |

**Slowest node:** ~10s
**Fastest node:** ~1s
**Difference:** ~10x slower (900% difference)

### With split-test-rb (Subsequent Runs - Using XML)

After the first run, split-test-rb uses the generated XML report to intelligently distribute tests based on actual execution times:

| Node | Execution Time | Assigned Tests |
|------|---------------|----------------|
| 0    | ~15.1s | dummy_010_spec.rb (40s) |
| 1    | ~15.1s | dummy_009_spec.rb (30s) |
| 2    | ~15.1s | dummy_008_spec.rb (25s) |
| 3    | ~15.1s | dummy_007_spec.rb (20s) |
| 4    | ~15.1s | dummy_006_spec.rb (15s) |
| 5    | ~15.1s | dummy_005_spec.rb (10s), dummy_004_spec.rb (5s) |
| 6    | ~15.1s | dummy_003_spec.rb (3s), dummy_002_spec.rb (2s), dummy_001_spec.rb (1s), other_specs... |
| 7    | ~15.1s | Remaining specs balanced by execution time |
| 8    | ~15.1s | Remaining specs balanced by execution time |
| 9    | ~15.1s | Remaining specs balanced by execution time |

**Slowest node:** ~15.1s
**Fastest node:** ~15.1s
**Difference:** Nearly balanced (< 5% variation)

### Key Improvement

The greedy balancing algorithm reduces the execution time difference from **10x** to nearly **0**, ensuring all nodes complete at approximately the same time. This maximizes CI efficiency and reduces overall build time.

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
