# split-test-rb

[![codecov](https://codecov.io/gh/naofumi-fujii/split-test-rb/branch/main/graph/badge.svg)](https://codecov.io/gh/naofumi-fujii/split-test-rb)

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

This project has real running example:
- [.github/workflows/ci.yml](https://github.com/naofumi-fujii/split-test-rb/blob/main/.github/workflows/ci.yml)

### Important: Merging Parallel Test Results

When running tests in parallel, each node generates its own JUnit XML file. These must be **properly merged** (not just concatenated) before being used for the next test run.

**❌ Wrong approach (loses test data):**
```bash
cat tmp/results/*.xml > merged.xml  # This creates invalid XML!
```

**✅ Correct approach:**
```bash
bundle exec bin/merge-junit-xml merged.xml tmp/results/*.xml
```

The `merge-junit-xml` utility properly combines multiple JUnit XML files into a single valid XML document, preserving all test timing data across nodes.

## How It Works

1. **Parse JUnit XML**: Extracts test file paths and execution times from the XML report
2. **Greedy Balancing**: Sorts files by execution time (descending) and assigns each file to the node with the lowest cumulative time
3. **Output**: Prints the list of test files for the specified node

## Fallback Behavior

split-test-rb provides intelligent fallback handling to ensure tests can run even without historical timing data:

### When XML file doesn't exist
If the specified XML file is not found, the tool will:
- Display a warning: `Warning: XML file not found: <path>, using all spec files with equal weights`
- Find all spec files matching `spec/**/*_spec.rb`
- Assign equal execution time (1.0 seconds) to each file
- Distribute them evenly across nodes

This is useful for:
- First-time runs when no test history exists yet
- Local development environments
- New CI pipelines

### When spec files are missing from XML
If new spec files exist that aren't in the XML report, the tool will:
- Display a warning: `Warning: Found N spec files not in XML, adding with default weight`
- Add the missing files with default execution time (1.0 seconds)
- Include them in the distribution

This ensures newly added test files are always included in the test run.

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
