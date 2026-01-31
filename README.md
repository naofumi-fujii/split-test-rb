# split-test-rb

[![codecov](https://codecov.io/gh/naofumi-fujii/split-test-rb/branch/main/graph/badge.svg)](https://codecov.io/gh/naofumi-fujii/split-test-rb)

A simple Ruby CLI tool to balance RSpec tests across parallel CI nodes using RSpec JSON reports.

## Overview

split-test-rb reads RSpec JSON test reports containing execution times and distributes test files across multiple nodes for parallel execution. It uses a greedy algorithm to ensure balanced distribution based on historical test execution times.

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
  --json-path PATH            Path to directory containing RSpec JSON reports (required)
  --test-dir DIR              Test directory (default: spec)
  --test-pattern PATTERN      Test file pattern (default: **/*_spec.rb)
  --exclude-pattern PATTERN   Pattern to exclude (can be specified multiple times)
  --debug                     Show debug information
  -h, --help                  Show help message
```

### Custom Test Directory and Pattern

By default, split-test-rb looks for test files in the `spec/` directory with the pattern `**/*_spec.rb`. You can customize this for projects with different test directory structures:

**Using Minitest with `test/` directory:**
```bash
split-test-rb --json-path tmp/test-results \
  --node-index $CI_NODE_INDEX \
  --node-total $CI_NODE_TOTAL \
  --test-dir test \
  --test-pattern '**/*_test.rb'
```

**Custom test directory structure:**
```bash
split-test-rb --json-path tmp/test-results \
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

### Excluding Specific Files or Directories

Use `--exclude-pattern` to exclude specific files or directories from test distribution. This is useful when you want to exclude slow tests or integration tests from parallel execution:

```bash
split-test-rb --json-path tmp/test-results \
  --node-index $CI_NODE_INDEX \
  --node-total $CI_NODE_TOTAL \
  --exclude-pattern '**/slow/**'
```

You can specify multiple exclude patterns:

```bash
split-test-rb --json-path tmp/test-results \
  --node-index $CI_NODE_INDEX \
  --node-total $CI_NODE_TOTAL \
  --exclude-pattern '**/slow/**' \
  --exclude-pattern '**/integration/**' \
  --exclude-pattern '**/*_slow_spec.rb'
```

This is useful for:
- Excluding slow feature specs from distribution on feature branches
- Excluding specific directories or file patterns
- Complementing RSpec's tag-based filtering with file-level exclusion

## How It Works

1. **Parse RSpec JSON**: Extracts test file paths and execution times from the JSON report
2. **Greedy Balancing**: Sorts files by execution time (descending) and assigns each file to the node with the lowest cumulative time
3. **Output**: Prints the list of test files for the specified node

## Fallback Behavior

split-test-rb provides intelligent fallback handling to ensure tests can run even without historical timing data:

### When JSON file doesn't exist
If the specified JSON file is not found, the tool will:
- Display a warning: `Warning: JSON directory not found: <path>, using all test files with equal execution time`
- Find all test files matching the specified directory and pattern (default: `spec/**/*_spec.rb`)
- Assign equal execution time (1.0 seconds) to each file
- Distribute them evenly across nodes

This is useful for:
- First-time runs when no test history exists yet
- Local development environments
- New CI pipelines

### When test files are missing from JSON
If new test files exist that aren't in the JSON report, the tool will:
- Display a warning: `Warning: Found N test files not in JSON, adding with default execution time`
- Add the missing files with default execution time (1.0 seconds)
- Include them in the distribution

This ensures newly added test files are always included in the test run.

## RSpec JSON Format

The tool expects [RSpec JSON output format](https://rspec.info/features/3-13/rspec-core/formatters/json-formatter/) (generated with `--format json`):

```json
{
  "examples": [
    {
      "file_path": "./spec/models/user_spec.rb",
      "run_time": 1.234
    },
    {
      "file_path": "./spec/models/post_spec.rb",
      "run_time": 0.567
    }
  ]
}
```

To generate JSON reports with RSpec, use the built-in JSON formatter:

```bash
bundle exec rspec --format json --out tmp/rspec-results/results.json
```

## License

MIT
