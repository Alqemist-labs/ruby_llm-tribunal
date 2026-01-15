# frozen_string_literal: true

require_relative 'lib/ruby_llm/tribunal/version'

Gem::Specification.new do |spec|
  spec.name = 'ruby_llm-tribunal'
  spec.version = RubyLLM::Tribunal::VERSION
  spec.authors = ['Florian']
  spec.email = ['florian@alqemist.com']

  spec.summary = 'LLM evaluation framework for Ruby'
  spec.description = <<~DESC.strip
    Tribunal provides tools for evaluating LLM outputs, detecting hallucinations,
    measuring response quality, and ensuring safety. Features deterministic assertions,
    LLM-as-judge evaluations, red team attack generation, and multiple output formats.
    A RubyLLM plugin inspired by the Elixir Tribunal library.
  DESC
  spec.homepage = 'https://github.com/Alqemist-labs/ruby_llm-tribunal'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.glob('{lib,exe}/**/*') + %w[README.md LICENSE.txt CHANGELOG.md]
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'ruby_llm', '~> 1.0'
end
