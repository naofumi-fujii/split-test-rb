require 'json'
require 'optparse'
require_relative 'split_test_rb/version'

module SplitTestRb
  # Parses RSpec JSON result files and extracts test timing data
  class JsonParser
    # Parses RSpec JSON file and returns hash of {file_path => execution_time}
    def self.parse(json_path)
      content = File.read(json_path)
      data = JSON.parse(content)
      timings = {}

      examples = data['examples'] || []
      examples.each do |example|
        file_path = extract_file_path(example)
        run_time = example['run_time'].to_f

        next unless file_path

        # Normalize path to ensure consistent format (remove leading ./)
        file_path = normalize_path(file_path)

        # Aggregate timing for files (sum if multiple test cases from same file)
        timings[file_path] ||= 0
        timings[file_path] += run_time
      end

      timings
    end

    # Extracts file path from example, preferring id field over file_path
    # This is important for shared examples where file_path points to the shared example file
    # but id contains the actual spec file path (e.g., "./spec/features/entry_spec.rb[1:1:1]")
    def self.extract_file_path(example)
      if example['id']
        # Extract file path from id (format: "./path/to/spec.rb[1:2:3]")
        example['id'].split('[').first
      else
        example['file_path']
      end
    end

    # Parses RSpec JSON file and returns hash of {example_id => execution_time}
    # Example ID format: "spec/file.rb[1:1]"
    def self.parse_with_examples(json_path)
      content = File.read(json_path)
      data = JSON.parse(content)
      timings = {}

      examples = data['examples'] || []
      examples.each do |example|
        next unless example['id']

        example_id = normalize_path(example['id'])
        run_time = example['run_time'].to_f

        timings[example_id] = run_time
      end

      timings
    end

    # Parses multiple JSON files and returns hash of {example_id => execution_time}
    def self.parse_files_with_examples(json_paths)
      timings = {}

      json_paths.each do |json_path|
        next unless File.exist?(json_path)
        next if File.empty?(json_path)

        begin
          example_timings = parse_with_examples(json_path)
          example_timings.each do |example_id, time|
            timings[example_id] = time
          end
        rescue JSON::ParserError => e
          warn "Warning: Failed to parse #{json_path}: #{e.message}"
        end
      end

      timings
    end

    # Parses all JSON files in a directory and merges results
    def self.parse_directory(dir_path)
      json_files = Dir.glob(File.join(dir_path, '**', '*.json'))
      parse_files(json_files)
    end

    # Parses multiple JSON files and merges results
    def self.parse_files(json_paths)
      timings = {}

      json_paths.each do |json_path|
        next unless File.exist?(json_path)
        next if File.empty?(json_path)

        begin
          file_timings = parse(json_path)
          file_timings.each do |file, time|
            timings[file] ||= 0
            timings[file] += time
          end
        rescue JSON::ParserError => e
          warn "Warning: Failed to parse #{json_path}: #{e.message}"
        end
      end

      timings
    end

    # Normalizes file path by removing leading ./
    def self.normalize_path(path)
      path.sub(%r{^\./}, '')
    end
  end

  # Balances test files across multiple nodes using greedy algorithm
  class Balancer
    # Distributes test files across nodes based on execution times
    # Uses greedy algorithm: assign each file to the node with lowest cumulative time
    def self.balance(timings, total_nodes)
      # Sort files by execution time (descending) for better balance
      sorted_files = timings.sort_by { |_file, time| -time }

      # Initialize nodes with empty arrays and zero cumulative time
      nodes = Array.new(total_nodes) { { files: [], total_time: 0 } }

      # Assign each file to the node with lowest cumulative time
      sorted_files.each do |file, time|
        # Find node with minimum total time
        min_node = nodes.min_by { |node| node[:total_time] }
        min_node[:files] << file
        min_node[:total_time] += time
      end

      nodes
    end
  end

  # Command-line interface
  class CLI
    def self.run(argv)
      options = parse_options(argv)
      validate_options!(options)

      timings, default_files, json_files = load_timings(options)
      exit_if_no_tests(timings)

      nodes = Balancer.balance(timings, options[:total_nodes])
      DebugPrinter.print(nodes, timings, default_files, json_files) if options[:debug]

      output_node_files(nodes, options[:node_index])
    end

    def self.validate_options!(options)
      return if options[:json_path]

      warn 'Error: --json-path is required'
      exit 1
    end

    def self.load_timings(options)
      json_dir = options[:json_path]

      if File.directory?(json_dir)
        load_timings_from_json(json_dir, options)
      else
        warn "Warning: JSON directory not found: #{json_dir}, using all test files with equal execution time"
        timings = find_all_spec_files(options[:test_dir], options[:test_pattern])
        [timings, Set.new(timings.keys), []]
      end
    end

    def self.load_timings_from_json(json_dir, options)
      json_files = Dir.glob(File.join(json_dir, '**', '*.json'))
      file_timings = JsonParser.parse_files(json_files)
      all_test_files = find_all_spec_files(options[:test_dir], options[:test_pattern])

      # Filter out files from JSON cache that don't match the test pattern
      file_timings.select! { |file, _| all_test_files.key?(file) }

      default_files = add_missing_files_with_default_timing(file_timings, all_test_files)

      # Apply example-level splitting if threshold is set
      threshold = options[:split_by_example_threshold]
      if threshold
        timings = apply_example_splitting(file_timings, json_files, threshold)
      else
        timings = file_timings
      end

      [timings, default_files, json_files]
    end

    # Splits heavy files (>= threshold) into individual examples
    def self.apply_example_splitting(file_timings, json_files, threshold)
      heavy_files = file_timings.select { |_file, time| time >= threshold }
      return file_timings if heavy_files.empty?

      example_timings = JsonParser.parse_files_with_examples(json_files)

      # Start with light files (below threshold)
      timings = file_timings.reject { |file, _| heavy_files.key?(file) }

      # Add individual examples from heavy files
      heavy_files.each_key do |heavy_file|
        example_timings.each do |example_id, time|
          timings[example_id] = time if example_id.start_with?(heavy_file)
        end
      end

      timings
    end

    # Adds test files missing from JSON results with default timing (1.0s)
    def self.add_missing_files_with_default_timing(timings, all_test_files)
      default_files = Set.new
      missing_files = all_test_files.keys - timings.keys

      return default_files if missing_files.empty?

      warn "Warning: Found #{missing_files.size} test files not in JSON, adding with default execution time"
      missing_files.each do |file|
        timings[file] = 1.0
        default_files.add(file)
      end

      default_files
    end

    def self.exit_if_no_tests(timings)
      return unless timings.empty?

      warn 'Warning: No test files found'
      exit 0
    end

    def self.output_node_files(nodes, node_index)
      node_files = nodes[node_index][:files]
      puts node_files.join("\n")
    end

    # Default option values for CLI
    DEFAULT_OPTIONS = {
      node_index: 0,
      total_nodes: 1,
      debug: false,
      test_dir: 'spec',
      test_pattern: '**/*_spec.rb',
      split_by_example_threshold: nil
    }.freeze

    # Parses command-line arguments and returns options hash
    def self.parse_options(argv)
      options = DEFAULT_OPTIONS.dup
      build_option_parser(options).parse!(argv)
      options
    end

    # Builds and configures the OptionParser instance
    def self.build_option_parser(options)
      OptionParser.new do |opts|
        opts.banner = 'Usage: split-test-rb [options]'
        define_options(opts, options)
      end
    end

    # Defines all CLI options on the given OptionParser
    def self.define_options(opts, options)
      define_node_options(opts, options)
      define_test_options(opts, options)
    end

    # Defines node distribution related CLI options
    def self.define_node_options(opts, options)
      opts.on('--node-index INDEX', Integer, 'Current node index (0-based)') { |v| options[:node_index] = v }
      opts.on('--node-total TOTAL', Integer, 'Total number of nodes') { |v| options[:total_nodes] = v }
      opts.on('--json-path PATH', 'Path to directory containing RSpec JSON reports') { |v| options[:json_path] = v }
    end

    # Defines test configuration and utility CLI options
    def self.define_test_options(opts, options)
      opts.on('--test-dir DIR', 'Test directory (default: spec)') { |v| options[:test_dir] = v }
      opts.on('--test-pattern PATTERN', 'Test file pattern (default: **/*_spec.rb)') { |v| options[:test_pattern] = v }
      opts.on('--split-by-example-threshold SECONDS', Float,
              'Split files with execution time >= threshold into individual examples') do |v|
        options[:split_by_example_threshold] = v
      end
      opts.on('--debug', 'Show debug information') { options[:debug] = true }
      opts.on('-h', '--help', 'Show this help message') do
        puts opts
        exit
      end
      opts.on('-v', '--version', 'Show version') do
        puts "split-test-rb #{VERSION}"
        exit
      end
    end

    def self.find_all_spec_files(test_dir = 'spec', test_pattern = '**/*_spec.rb')
      # Find all test files in the specified directory with the given pattern
      glob_pattern = File.join(test_dir, test_pattern)
      test_files = Dir.glob(glob_pattern)
      # Normalize paths and assign equal execution time (1.0) to each file
      test_files.each_with_object({}) do |file, hash|
        normalized_path = JsonParser.normalize_path(file)
        hash[normalized_path] = 1.0
      end
    end
  end

  # Outputs debug information about test distribution
  module DebugPrinter
    # Shows distribution statistics, timing data sources, and per-node assignments
    def self.print(nodes, timings, default_files, json_files)
      total_files = timings.size
      total_time = timings.values.sum.round(2)
      files_from_xml = total_files - default_files.size
      avg_time, variance, max_deviation = calculate_load_balance_stats(nodes, total_time)

      warn '=== Test Balancing Debug Info ==='
      warn ''
      print_loaded_json_files(json_files, timings)
      print_timing_data_source(files_from_xml, default_files.size, total_files, total_time)
      print_load_balance_stats(avg_time, max_deviation)
      print_node_distribution(nodes, variance, timings, default_files)
      warn '===================================='
    end

    # Prints information about loaded JSON result files
    def self.print_loaded_json_files(json_files, timings)
      warn '## Loaded Test Result Files'
      if json_files.empty?
        warn '  (no JSON files loaded)'
      else
        json_files.each do |file|
          warn "  - #{file}"
        end
        warn "  Total: #{json_files.size} JSON files, #{timings.size} test files extracted"
      end
      warn ''
    end

    # Calculates load balance statistics across nodes
    def self.calculate_load_balance_stats(nodes, total_time)
      avg_time = total_time / nodes.size
      variance = nodes.map { |n| ((n[:total_time] - avg_time) / avg_time * 100).round(1) }
      max_deviation = variance.map(&:abs).max
      [avg_time, variance, max_deviation]
    end

    # Prints timing data source information
    def self.print_timing_data_source(files_from_xml, default_files_count, total_files, total_time)
      warn '## Timing Data Source (from past test execution results)'
      warn "  - Files with historical timing: #{files_from_xml} files"
      warn "  - Files with default timing (1.0s): #{default_files_count} files"
      warn "  - Total files: #{total_files} files"
      warn "  - Total estimated time: #{total_time}s"
      warn ''
    end

    # Prints load balance statistics
    def self.print_load_balance_stats(avg_time, max_deviation)
      warn '## Load Balance'
      warn "  - Average time per node: #{avg_time.round(2)}s"
      warn "  - Max deviation from average: #{max_deviation}%"
      warn ''
    end

    # Prints per-node distribution details
    def self.print_node_distribution(nodes, variance, timings, default_files)
      warn '## Per-Node Distribution'
      nodes.each_with_index do |node, index|
        print_node_info(node, index, variance[index], timings, default_files)
      end
    end

    # Prints information for a single node
    def self.print_node_info(node, index, deviation, timings, default_files)
      deviation_str = deviation >= 0 ? "+#{deviation}%" : "#{deviation}%"
      warn "Node #{index}: #{node[:files].size} files, #{node[:total_time].round(2)}s (#{deviation_str} from avg)"
      node[:files].each do |file|
        warn "  - #{file} #{format_file_timing(file, timings, default_files)}"
      end
      warn ''
    end

    # Formats file timing information with labels
    def self.format_file_timing(file, timings, default_files)
      time = timings[file]
      timing_str = "(#{time.round(2)}s"
      timing_str += ', default - no historical data' if default_files.include?(file)
      timing_str += ')'
      timing_str
    end
  end
end
