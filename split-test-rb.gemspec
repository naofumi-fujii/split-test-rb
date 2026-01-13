Gem::Specification.new do |spec|
  spec.name          = 'split-test-rb'
  spec.version       = '0.1.0'
  spec.authors       = ['Naofumi Fujii']
  spec.summary       = 'Split tests across multiple nodes based on timing data'
  spec.description   = 'A simple CLI tool to balance RSpec tests across parallel CI nodes using JUnit XML reports'
  spec.homepage      = 'https://github.com/naofumi-fujii/split-test-rb'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.files         = Dir['lib/**/*', 'bin/*', 'LICENSE', 'README.md']
  spec.bindir        = 'bin'
  spec.executables   = ['split-test-rb']
  spec.require_paths = ['lib']

  spec.add_dependency 'nokogiri', '~> 1.13'

  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rspec_junit_formatter', '~> 0.6'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'rubocop-rspec', '~> 3.9'
  spec.add_development_dependency 'simplecov', '~> 0.22'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
