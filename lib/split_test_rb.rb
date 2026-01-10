require 'nokogiri'
require 'optparse'
require 'set'

module SplitTestRb
  # Parses JUnit XML files and extracts test timing data
  class JunitParser
    # Parses JUnit XML file(s) and returns hash of {file_path => execution_time}
    # Accepts either a single XML file path or a directory containing XML files
    def self.parse(xml_path)
      files = if File.directory?(xml_path)
                Dir.glob(File.join(xml_path, '*.xml')).sort
              elsif File.file?(xml_path)
                [xml_path]
              else
                []
              end

      timings = {}
      files.each do |file|
        parse_file(file, timings)
      end

      timings
    end

    # Parses a single JUnit XML file and aggregates timings into the provided hash
    def self.parse_file(xml_path, timings = {})
      doc = File.open(xml_path) { |f| Nokogiri::XML(f) }

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

      # Parse JUnit XML and get timings, or use all spec files if XML doesn't exist
      default_files = Set.new
      if File.exist?(options[:xml_path])
        # Show which XML files will be processed if it's a directory
        if File.directory?(options[:xml_path])
          xml_files = Dir.glob(File.join(options[:xml_path], '*.xml')).sort
          if options[:debug]
            if xml_files.empty?
              warn "Info: No XML files found in #{options[:xml_path]}"
            else
              warn "Info: Loading timing data from #{xml_files.size} XML file(s):"
              xml_files.each { |f| warn "  - #{File.basename(f)}" }
            end
          end
        end

        timings = JunitParser.parse(options[:xml_path])

        # Find all spec files and add any missing ones with default weight
        all_spec_files = find_all_spec_files
        missing_files = all_spec_files.keys - timings.keys
        unless missing_files.empty?
          warn "Warning: Found #{missing_files.size} spec files not in XML, adding with default weight"
          missing_files.each do |file|
            timings[file] = 1.0
            default_files.add(file)
          end
        end
      else
        warn "Warning: XML path not found: #{options[:xml_path]}, using all spec files with equal weights"
        timings = find_all_spec_files
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

        opts.on('--xml-path PATH', 'Path to JUnit XML report file or directory') do |v|
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

    def self.find_all_spec_files
      # Find all spec files in the spec directory
      spec_files = Dir.glob('spec/**/*_spec.rb')
      # Normalize paths and assign equal weight (1.0) to each file
      spec_files.each_with_object({}) do |file, hash|
        normalized_path = JunitParser.normalize_path(file)
        hash[normalized_path] = 1.0
      end
    end

    def self.print_debug_info(nodes, timings, default_files)
      warn '=== Test Distribution ==='
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
