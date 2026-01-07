require 'nokogiri'
require 'optparse'

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

        # Aggregate timing for files (sum if multiple test cases from same file)
        timings[file_path] ||= 0
        timings[file_path] += time
      end

      timings
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
        puts 'Error: --xml-path is required'
        exit 1
      end

      unless File.exist?(options[:xml_path])
        puts "Error: XML file not found: #{options[:xml_path]}"
        exit 1
      end

      # Parse JUnit XML and get timings
      timings = JunitParser.parse(options[:xml_path])

      if timings.empty?
        puts 'Warning: No test timings found in XML file'
        exit 0
      end

      # Balance tests across nodes
      nodes = Balancer.balance(timings, options[:total_nodes])

      if options[:debug]
        print_debug_info(nodes)
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

        opts.on('--xml-path PATH', 'Path to JUnit XML report') do |v|
          options[:xml_path] = v
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

    def self.print_debug_info(nodes)
      warn '=== Test Distribution ==='
      nodes.each_with_index do |node, index|
        warn "Node #{index}: #{node[:files].size} files, #{node[:total_time].round(2)}s total"
        node[:files].each do |file|
          warn "  - #{file}"
        end
      end
      warn '========================='
    end
  end
end
