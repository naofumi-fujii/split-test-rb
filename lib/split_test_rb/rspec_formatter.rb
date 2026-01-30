require 'rspec/core'
require 'rspec/core/formatters/documentation_formatter'

module SplitTestRb
  # Custom RSpec formatter that shows filename with each example
  class RSpecFormatter < RSpec::Core::Formatters::DocumentationFormatter
    RSpec::Core::Formatters.register self, :example_started, :example_passed, :example_pending, :example_failed

    def example_passed(notification)
      output.puts passed_output(notification.example)
    end

    def example_pending(notification)
      output.puts pending_output(notification.example, notification.example.execution_result.pending_message)
    end

    def example_failed(notification)
      output.puts failure_output(notification.example)
    end

    private

    def passed_output(example)
      "#{current_indentation}#{format_example(example, success_color(example.description))}"
    end

    def pending_output(example, message)
      "#{current_indentation}#{format_example(example, pending_color("#{example.description} (PENDING: #{message})"))}"
    end

    def failure_output(example)
      "#{current_indentation}#{format_example(example, failure_color("#{example.description} (FAILED - #{next_failure_index})"))}"
    end

    def format_example(example, description)
      "#{description} #{file_location(example)}"
    end

    def file_location(example)
      location = example.location
      RSpec::Core::Formatters::ConsoleCodes.wrap(location, :cyan)
    end
  end
end
