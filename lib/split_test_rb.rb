require 'nokogiri'
require 'optparse'
require 'set'

module SplitTestRb
  # Parses JUnit XML files and extracts test timing data
  class JunitParser
    # Parses JUnit XML file and returns hash of {file_path => execution_time}
    def self.parse(xml_path)
      doc = File.open(xml_path) { |f| Nokogiri::XML(f) }
      timings = {}

      doc.xpath('//testcase').each do |testcase|
        # Try different attribute names for file path
        file_path = testcase['file'] || testcase['filepath']
        time = testcase['time'].to_f

        next unless file_path

        # Normalize path to ensure consistent format (remove leading ./)
        file_path = normalize_path(file_path)

        # Aggregate timing for files (sum if multiple test cases from same file)
        timings[file_path] ||= 0
        timings[file_path] += time
      end

      timings
    end

    # Parses all XML files in a directory and merges results
    def self.parse_directory(dir_path)
      xml_files = Dir.glob(File.join(dir_path, '**', '*.xml'))
      parse_files(xml_files)
    end

    # Parses multiple XML files and merges results
    def self.parse_files(xml_paths)
      timings = {}

      xml_paths.each do |xml_path|
        next unless File.exist?(xml_path)

        file_timings = parse(xml_path)
        file_timings.each do |file, time|
          timings[file] ||= 0
          timings[file] += time
        end
      end

      timings
    end


    # Normalizes file path by removing leading ./
    def self.normalize_path(path)
      path.sub(/^\.\//, '')
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

      unless options[:xml_path]
        warn 'Error: --xml-path is required'
        exit 1
      end

      unless options[:test_dir]
        warn 'Error: --test-dir is required'
        exit 1
      end

      unless options[:test_pattern]
        warn 'Error: --test-pattern is required'
        exit 1
      end

      # Parse JUnit XML files from directory and get timings, or use all test files if directory doesn't exist
      default_files = Set.new
      xml_dir = options[:xml_path]
      if File.directory?(xml_dir)
        timings = JunitParser.parse_directory(xml_dir)
        # Find all test files and add any missing ones with default execution time
        all_test_files = find_all_spec_files(options[:test_dir], options[:test_pattern])
        missing_files = all_test_files.keys - timings.keys
        unless missing_files.empty?
          warn "Warning: Found #{missing_files.size} test files not in XML, adding with default execution time"
          missing_files.each do |file|
            timings[file] = 1.0
            default_files.add(file)
          end
        end
      else
        warn "Warning: XML directory not found: #{xml_dir}, using all test files with equal execution time"
        timings = find_all_spec_files(options[:test_dir], options[:test_pattern])
        default_files = Set.new(timings.keys)
      end

      if timings.empty?
        warn 'Warning: No test files found'
        exit 0
      end

      # Balance tests across nodes
      nodes = Balancer.balance(timings, options[:total_nodes])

      if options[:debug]
        print_debug_info(nodes, timings, default_files)
      end

      # Output files for the specified node
      node_files = nodes[options[:node_index]][:files]
      puts node_files.join("\n")
    end

    def self.parse_options(argv)
      options = {
        node_index: 0,
        total_nodes: 1,
        debug: false
      }

      OptionParser.new do |opts|
        opts.banner = 'Usage: split-test-rb [options]'

        opts.on('--node-index INDEX', Integer, 'Current node index (0-based)') do |v|
          options[:node_index] = v
        end

        opts.on('--node-total TOTAL', Integer, 'Total number of nodes') do |v|
          options[:total_nodes] = v
        end

        opts.on('--xml-path PATH', 'Path to directory containing JUnit XML reports') do |v|
          options[:xml_path] = v
        end

        opts.on('--test-dir DIR', 'Test directory (required)') do |v|
          options[:test_dir] = v
        end

        opts.on('--test-pattern PATTERN', 'Test file pattern (required)') do |v|
          options[:test_pattern] = v
        end

        opts.on('--debug', 'Show debug information') do
          options[:debug] = true
        end

        opts.on('-h', '--help', 'Show this help message') do
          puts opts
          exit
        end
      end.parse!(argv)

      options
    end

    def self.find_all_spec_files(test_dir = 'spec', test_pattern = '**/*_spec.rb')
      # Find all test files in the specified directory with the given pattern
      glob_pattern = File.join(test_dir, test_pattern)
      test_files = Dir.glob(glob_pattern)
      # Normalize paths and assign equal execution time (1.0) to each file
      test_files.each_with_object({}) do |file, hash|
        normalized_path = JunitParser.normalize_path(file)
        hash[normalized_path] = 1.0
      end
    end

    def self.print_debug_info(nodes, timings, default_files)
      total_files = timings.size
      total_time = timings.values.sum.round(2)

      warn '=== Test Distribution ==='
      warn "Total: #{total_files} test files, #{total_time}s total"
      warn ''
      nodes.each_with_index do |node, index|
        warn "Node #{index}: #{node[:files].size} files, #{node[:total_time].round(2)}s total"
        node[:files].each do |file|
          time = timings[file]
          time_str = "(#{time.round(2)}s"
          time_str += ', default' if default_files.include?(file)
          time_str += ')'
          warn "  - #{file} #{time_str}"
        end
      end
      warn '========================='
    end
  end
end
