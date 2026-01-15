# frozen_string_literal: true

RSpec.describe RubyLLM::Tribunal do
  it 'has a version number' do
    expect(RubyLLM::Tribunal::VERSION).not_to be_nil
  end

  describe '.test_case' do
    it 'creates a new test case' do
      test_case = described_class.test_case(
        input: "What's the price?",
        actual_output: 'The price is $29.99.',
        context: ['Product costs $29.99']
      )

      expect(test_case).to be_a(RubyLLM::Tribunal::TestCase)
      expect(test_case.input).to eq("What's the price?")
      expect(test_case.actual_output).to eq('The price is $29.99.')
      expect(test_case.context).to eq(['Product costs $29.99'])
    end
  end

  describe '.evaluate' do
    it 'evaluates a test case against assertions' do
      test_case = described_class.test_case(
        input: 'test',
        actual_output: 'Hello world, price is $29.99'
      )

      assertions = [
        [:contains, { value: 'Hello' }],
        [:regex, { value: /\$\d+\.\d{2}/ }]
      ]

      results = described_class.evaluate(test_case, assertions)

      expect(results[:contains].first).to eq(:pass)
      expect(results[:regex].first).to eq(:pass)
    end
  end

  describe '.available_assertions' do
    it 'includes deterministic assertions' do
      available = described_class.available_assertions

      expect(available).to include(:contains)
      expect(available).to include(:not_contains)
      expect(available).to include(:regex)
      expect(available).to include(:is_json)
      expect(available).to include(:max_tokens)
      expect(available).to include(:starts_with)
      expect(available).to include(:ends_with)
      expect(available).to include(:equals)
      expect(available).to include(:min_length)
      expect(available).to include(:max_length)
      expect(available).to include(:word_count)
      expect(available).to include(:is_url)
      expect(available).to include(:is_email)
      expect(available).to include(:levenshtein)
    end

    it 'includes judge assertions' do
      available = described_class.available_assertions

      expect(available).to include(:faithful)
      expect(available).to include(:relevant)
      expect(available).to include(:hallucination)
      expect(available).to include(:correctness)
      expect(available).to include(:bias)
      expect(available).to include(:toxicity)
      expect(available).to include(:harmful)
      expect(available).to include(:jailbreak)
      expect(available).to include(:pii)
      expect(available).to include(:refusal)
    end
  end

  describe '.configure' do
    it 'allows configuration' do
      described_class.configure do |config|
        config.default_model = 'openai:gpt-4o'
        config.default_threshold = 0.9
        config.verbose = true
      end

      expect(described_class.configuration.default_model).to eq('openai:gpt-4o')
      expect(described_class.configuration.default_threshold).to eq(0.9)
      expect(described_class.configuration.verbose).to be(true)

      # Reset
      described_class.configure do |config|
        config.default_model = 'anthropic:claude-3-5-haiku-latest'
        config.default_threshold = 0.8
        config.verbose = false
      end
    end
  end
end
