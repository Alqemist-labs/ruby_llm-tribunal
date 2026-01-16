# frozen_string_literal: true

require 'ruby_llm/tribunal'

namespace :tribunal do
  desc 'Run LLM evaluations from dataset files'
  task :eval, [:files] => :environment do |_t, args|
    options = parse_options

    files = if args[:files]
              args[:files].split(',')
            elsif options[:files]
              options[:files]
            else
              find_default_files
            end

    if files.empty?
      puts 'No eval files found. Create datasets in test/evals/ or spec/evals/'
      exit 0
    end

    provider = parse_provider(options[:provider])
    format = options[:format] || 'console'
    output = options[:output]
    threshold = options[:threshold]
    strict = options[:strict] || false
    concurrency = options[:concurrency] || 1

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)

    results = files.flat_map { |file| load_and_run(file, provider, concurrency) }
    aggregated = aggregate_results(results, start_time)

    # Determine pass/fail based on threshold
    passed = if strict
               aggregated[:summary][:failed].zero?
             elsif threshold
               aggregated[:summary][:pass_rate] >= threshold
             else
               true
             end

    aggregated[:summary][:threshold_passed] = passed
    aggregated[:summary][:threshold] = threshold
    aggregated[:summary][:strict] = strict

    formatted = RubyLLM::Tribunal::Reporter.format(aggregated, format)

    if output
      File.write(output, formatted)
      puts "Results written to #{output}"
    else
      puts formatted
    end

    exit 1 unless passed
  end

  desc 'Initialize eval directory structure'
  task :init do
    base_dir = ENV.fetch('TRIBUNAL_BASE_DIR', '.')

    create_dir(File.join(base_dir, 'test/evals'))
    create_dir(File.join(base_dir, 'test/evals/datasets'))

    create_file(File.join(base_dir, 'test/evals/datasets/example.json'), example_dataset_json)
    create_file(File.join(base_dir, 'test/evals/datasets/example.yaml'), example_dataset_yaml)

    puts <<~MSG

      ✅ Created eval structure:

          test/evals/
          └── datasets/
              ├── example.json
              └── example.yaml

      Run evals with: rake tribunal:eval
    MSG
  end

  private

  def parse_options
    options = {}
    ARGV.each do |arg|
      case arg
      when /^--format=(.+)$/
        options[:format] = Regexp.last_match(1)
      when /^--output=(.+)$/
        options[:output] = Regexp.last_match(1)
      when /^--provider=(.+)$/
        options[:provider] = Regexp.last_match(1)
      when /^--threshold=(.+)$/
        options[:threshold] = Regexp.last_match(1).to_f
      when '--strict'
        options[:strict] = true
      when /^--concurrency=(.+)$/
        options[:concurrency] = Regexp.last_match(1).to_i
      when /^--files=(.+)$/
        options[:files] = Regexp.last_match(1).split(',')
      end
    end
    options
  end

  def find_default_files
    patterns = [
      'test/evals/**/*.json',
      'test/evals/**/*.yaml',
      'test/evals/**/*.yml',
      'spec/evals/**/*.json',
      'spec/evals/**/*.yaml',
      'spec/evals/**/*.yml'
    ]
    patterns.flat_map { |p| Dir.glob(p) }
  end

  def parse_provider(str)
    return nil unless str

    parts = str.split(':')
    raise 'Invalid provider format. Use Module:method (e.g. MyApp::RAG:query)' unless parts.length == 2

    mod = parts[0].split('::').reduce(Object) { |m, c| m.const_get(c) }
    [mod, parts[1].to_sym]
  end

  def load_and_run(path, provider, concurrency)
    puts "Loading #{path}..."

    cases = RubyLLM::Tribunal::Dataset.load_with_assertions(path)

    if concurrency > 1
      begin
        require 'parallel'
        Parallel.map(cases, in_threads: concurrency) do |test_case, assertions|
          run_case(test_case, assertions, provider)
        end
      rescue LoadError
        warn "Warning: 'parallel' gem not installed, falling back to sequential execution."
        warn '  Install with: gem install parallel'
        cases.map { |test_case, assertions| run_case(test_case, assertions, provider) }
      end
    else
      cases.map { |test_case, assertions| run_case(test_case, assertions, provider) }
    end
  end

  def run_case(test_case, assertions, provider)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)

    if provider
      mod, method = provider
      output = mod.send(method, test_case)
      test_case = test_case.with_output(output)
    end

    results = if test_case.actual_output
                RubyLLM::Tribunal::Assertions.evaluate_all(assertions, test_case)
              else
                {}
              end

    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - start

    failures = results
               .select { |_type, result| result.first == :fail }
               .map { |type, (_status, details)| [type, details[:reason]] }

    {
      input: test_case.input,
      status: failures.empty? ? :passed : :failed,
      failures:,
      results:,
      duration_ms: duration
    }
  end

  def aggregate_results(cases, start_time)
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond) - start_time

    passed = cases.count { |c| c[:status] == :passed }
    failed = cases.count { |c| c[:status] == :failed }
    total = cases.length

    metrics = aggregate_metrics(cases)

    {
      summary: {
        total:,
        passed:,
        failed:,
        pass_rate: total.positive? ? passed.to_f / total : 0,
        duration_ms: duration
      },
      metrics:,
      cases:
    }
  end

  def aggregate_metrics(cases)
    cases
      .flat_map { |c| c[:results].map { |type, result| [type, result.first == :pass] } }
      .group_by(&:first)
      .transform_values do |results|
        {
          passed: results.count { |_, passed| passed },
          total: results.length
        }
      end
  end

  def create_dir(path)
    FileUtils.mkdir_p(path)
    puts "Created #{path}/"
  end

  def create_file(path, content)
    return if File.exist?(path)

    File.write(path, content)
    puts "Created #{path}"
  end

  def example_dataset_json
    <<~JSON
      [
        {
          "input": "What is the return policy?",
          "context": "Returns are accepted within 30 days of purchase with a valid receipt. Items must be in original condition.",
          "expected": {
            "contains": ["30 days", "receipt"],
            "not_contains": ["no returns"]
          }
        },
        {
          "input": "Do you ship internationally?",
          "context": "We currently ship to the United States and Canada only.",
          "expected": {
            "contains_any": ["United States", "US", "Canada"],
            "not_contains": ["worldwide", "international"]
          }
        }
      ]
    JSON
  end

  def example_dataset_yaml
    <<~YAML
      - input: What is the return policy?
        context: Returns are accepted within 30 days of purchase with a valid receipt.
        expected:
          contains:
            - 30 days
            - receipt

      - input: What are the store hours?
        context: We are open Monday through Friday, 9am to 5pm.
        expected:
          contains_any:
            - "9am"
            - "9:00"
          regex: "\\\\d+[ap]m"
    YAML
  end
end

# Make tasks available without :environment for non-Rails apps
unless Rake::Task.task_defined?(:environment)
  task :environment do
    # No-op for non-Rails apps
  end
end
