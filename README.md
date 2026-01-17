# split-test-rb

[![codecov](https://codecov.io/gh/naofumi-fujii/split-test-rb/branch/main/graph/badge.svg)](https://codecov.io/gh/naofumi-fujii/split-test-rb)

A simple Ruby CLI tool to balance RSpec tests across parallel CI nodes using test timing data.

## Overview

split-test-rb reads test reports containing execution times and distributes test files across multiple nodes for parallel execution. It uses a greedy algorithm to ensure balanced distribution based on historical test execution times.

Supported formats:
- RSpec JSON formatter (built-in, no gem required)
- JUnit XML reports (via rspec_junit_formatter gem)

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

## GitHub Actions Example

First, add split-test-rb to your Gemfile:

```ruby
# Gemfile
gem 'split-test-rb', github: 'naofumi-fujii/split-test-rb'
```

For a working example, see this project's own CI configuration:
- [.github/workflows/ci.yml](https://github.com/naofumi-fujii/split-test-rb/blob/main/.github/workflows/ci.yml)

## Usage

### Command Line Options

```
split-test-rb [options]

Options:
  --node-index INDEX          Current node index (0-based)
  --node-total TOTAL          Total number of nodes
  --xml-path PATH             Path to directory containing test results (JUnit XML or RSpec JSON) (required)
  --test-dir DIR              Test directory (default: spec)
  --test-pattern PATTERN      Test file pattern (default: **/*_spec.rb)
  --debug                     Show debug information
  -h, --help                  Show help message
```

Note: The tool auto-detects the format based on file extensions (.xml or .json) in the results directory.

### Custom Test Directory and Pattern

By default, split-test-rb looks for test files in the `spec/` directory with the pattern `**/*_spec.rb`. You can customize this for projects with different test directory structures:

**Using Minitest with `test/` directory:**
```bash
split-test-rb --xml-path tmp/test-results \
  --node-index $CI_NODE_INDEX \
  --node-total $CI_NODE_TOTAL \
  --test-dir test \
  --test-pattern '**/*_test.rb'
```

**Custom test directory structure:**
```bash
split-test-rb --xml-path tmp/test-results \
  --node-index 0 \
  --node-total 4 \
  --test-dir tests \
  --test-pattern 'unit/**/*.rb'
```

The test directory and pattern options are useful for:
- Projects using Minitest (`test/` directory)
- Custom test directory structures
- Different naming conventions for test files
- Monorepos with multiple test suites

## How It Works

1. **Parse Test Results**: Extracts test file paths and execution times from test reports (auto-detects JSON or XML format)
2. **Greedy Balancing**: Sorts files by execution time (descending) and assigns each file to the node with the lowest cumulative time
3. **Output**: Prints the list of test files for the specified node

## Fallback Behavior

split-test-rb provides intelligent fallback handling to ensure tests can run even without historical timing data:

### When results directory doesn't exist
If the specified results directory is not found, the tool will:
- Display a warning: `Warning: Results directory not found: <path>, using all test files with equal execution time`
- Find all test files matching the specified directory and pattern (default: `spec/**/*_spec.rb`)
- Assign equal execution time (1.0 seconds) to each file
- Distribute them evenly across nodes

This is useful for:
- First-time runs when no test history exists yet
- Local development environments
- New CI pipelines

### When test files are missing from results
If new test files exist that aren't in the test results, the tool will:
- Display a warning: `Warning: Found N test files not in JSON/XML, adding with default execution time`
- Add the missing files with default execution time (1.0 seconds)
- Include them in the distribution

This ensures newly added test files are always included in the test run.

## Test Result Formats

### RSpec JSON Format (Recommended)

RSpec has a built-in JSON formatter that requires no additional gems. This is the recommended approach:

**Configure in .rspec:**
```
--format json
--out tmp/rspec-results.json
```

**Or use command line:**
```bash
bundle exec rspec --format json --out tmp/rspec-results.json
```

The JSON formatter outputs test timing data in the following structure:
```json
{
  "examples": [
    {
      "file_path": "spec/models/user_spec.rb",
      "run_time": 1.234
    }
  ]
}
```

### JUnit XML Format (Alternative)

Alternatively, you can use JUnit XML format with the `rspec_junit_formatter` gem:

**Add to Gemfile:**
```ruby
gem 'rspec_junit_formatter'
```

**Configure in .rspec:**
```
--format RspecJunitFormatter
--out tmp/rspec-results.xml
```

The tool expects JUnit XML with `file` or `filepath` attributes on testcase elements:

```xml
<testsuite>
  <testcase file="spec/models/user_spec.rb" time="1.234" />
  <testcase file="spec/models/post_spec.rb" time="0.567" />
</testsuite>
```

## License

MIT
