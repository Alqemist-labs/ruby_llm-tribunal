# frozen_string_literal: true

RSpec.describe RubyLLM::Tribunal::Assertions::Deterministic do
  describe ':contains' do
    it 'passes when substring found' do
      result = described_class.evaluate(:contains, 'Hello world', value: 'world')
      expect(result).to eq([:pass, { matched: ['world'] }])
    end

    it 'passes with multiple values' do
      result = described_class.evaluate(:contains, 'Hello world', values: %w[Hello world])
      expect(result.first).to eq(:pass)
    end

    it 'fails when substring missing' do
      result = described_class.evaluate(:contains, 'Hello world', value: 'foo')
      expect(result.first).to eq(:fail)
      expect(result.last[:missing]).to eq(['foo'])
    end
  end

  describe ':not_contains' do
    it 'passes when substring not found' do
      result = described_class.evaluate(:not_contains, 'Hello world', value: 'foo')
      expect(result.first).to eq(:pass)
    end

    it 'fails when substring found' do
      result = described_class.evaluate(:not_contains, 'Hello world', value: 'world')
      expect(result.first).to eq(:fail)
      expect(result.last[:found]).to eq(['world'])
    end
  end

  describe ':contains_any' do
    it 'passes when at least one found' do
      result = described_class.evaluate(:contains_any, 'Hello world', values: %w[foo world])
      expect(result).to eq([:pass, { matched: 'world' }])
    end

    it 'fails when none found' do
      result = described_class.evaluate(:contains_any, 'Hello world', values: %w[foo bar])
      expect(result.first).to eq(:fail)
    end
  end

  describe ':contains_all' do
    it 'passes when all found' do
      result = described_class.evaluate(:contains_all, 'Hello world', values: %w[Hello world])
      expect(result.first).to eq(:pass)
    end

    it 'fails when some missing' do
      result = described_class.evaluate(:contains_all, 'Hello world', values: %w[Hello foo])
      expect(result.first).to eq(:fail)
      expect(result.last[:missing]).to eq(['foo'])
    end
  end

  describe ':regex' do
    it 'passes with matching regex' do
      result = described_class.evaluate(:regex, 'Price: $29.99', value: /\$\d+\.\d{2}/)
      expect(result.first).to eq(:pass)
      expect(result.last[:matched]).to eq('$29.99')
    end

    it 'passes with string pattern' do
      result = described_class.evaluate(:regex, 'Price: $29.99', value: '\$\d+\.\d{2}')
      expect(result.first).to eq(:pass)
    end

    it 'fails when no match' do
      result = described_class.evaluate(:regex, 'Hello world', value: /\d+/)
      expect(result.first).to eq(:fail)
    end
  end

  describe ':is_json' do
    it 'passes with valid JSON' do
      result = described_class.evaluate(:is_json, '{"name": "test"}', {})
      expect(result.first).to eq(:pass)
      expect(result.last[:parsed]).to eq({ 'name' => 'test' })
    end

    it 'fails with invalid JSON' do
      result = described_class.evaluate(:is_json, 'not json', {})
      expect(result).to eq([:fail, { reason: 'Invalid JSON' }])
    end
  end

  describe ':max_tokens' do
    it 'passes under limit' do
      result = described_class.evaluate(:max_tokens, 'Short response', max: 100)
      expect(result.first).to eq(:pass)
    end

    it 'fails over limit' do
      long_text = 'word ' * 200
      result = described_class.evaluate(:max_tokens, long_text, max: 50)
      expect(result.first).to eq(:fail)
      expect(result.last[:reason]).to include('exceeds')
    end
  end

  describe ':latency_ms' do
    it 'passes under limit' do
      result = described_class.evaluate(:latency_ms, 'output', max: 1000, actual: 500)
      expect(result.first).to eq(:pass)
    end

    it 'fails over limit' do
      result = described_class.evaluate(:latency_ms, 'output', max: 1000, actual: 1500)
      expect(result.first).to eq(:fail)
      expect(result.last[:reason]).to include('exceeds')
    end

    it 'fails without actual value' do
      result = described_class.evaluate(:latency_ms, 'output', max: 1000)
      expect(result.first).to eq(:fail)
      expect(result.last[:reason]).to include('No latency')
    end
  end

  describe ':starts_with' do
    it 'passes when output starts with value' do
      result = described_class.evaluate(:starts_with, 'Hello world', value: 'Hello')
      expect(result).to eq([:pass, { prefix: 'Hello' }])
    end

    it 'fails when output does not start with value' do
      result = described_class.evaluate(:starts_with, 'Hello world', value: 'Goodbye')
      expect(result.first).to eq(:fail)
    end
  end

  describe ':ends_with' do
    it 'passes when output ends with value' do
      result = described_class.evaluate(:ends_with, 'Hello world', value: 'world')
      expect(result).to eq([:pass, { suffix: 'world' }])
    end

    it 'fails when output does not end with value' do
      result = described_class.evaluate(:ends_with, 'Hello world', value: 'universe')
      expect(result.first).to eq(:fail)
    end
  end

  describe ':equals' do
    it 'passes when output exactly matches' do
      result = described_class.evaluate(:equals, 'exact match', value: 'exact match')
      expect(result).to eq([:pass, {}])
    end

    it 'fails when output differs' do
      result = described_class.evaluate(:equals, 'bar', value: 'foo')
      expect(result.first).to eq(:fail)
    end
  end

  describe ':min_length' do
    it 'passes when output meets minimum length' do
      result = described_class.evaluate(:min_length, 'Hello world', value: 5)
      expect(result.first).to eq(:pass)
      expect(result.last[:length]).to eq(11)
    end

    it 'fails when output is too short' do
      result = described_class.evaluate(:min_length, 'Hi', value: 10)
      expect(result.first).to eq(:fail)
    end
  end

  describe ':max_length' do
    it 'passes when output is under max length' do
      result = described_class.evaluate(:max_length, 'Hello world', value: 100)
      expect(result.first).to eq(:pass)
    end

    it 'fails when output exceeds max length' do
      result = described_class.evaluate(:max_length, 'Hello world', value: 5)
      expect(result.first).to eq(:fail)
    end
  end

  describe ':word_count' do
    it 'passes when word count is within range' do
      result = described_class.evaluate(:word_count, 'Hello world', min: 1, max: 10)
      expect(result.first).to eq(:pass)
      expect(result.last[:word_count]).to eq(2)
    end

    it 'fails when word count is below minimum' do
      result = described_class.evaluate(:word_count, 'Hello', min: 5)
      expect(result.first).to eq(:fail)
    end

    it 'fails when word count exceeds maximum' do
      result = described_class.evaluate(:word_count, 'one two three four five', max: 2)
      expect(result.first).to eq(:fail)
    end
  end

  describe ':is_url' do
    it 'passes with valid URL' do
      result = described_class.evaluate(:is_url, 'https://example.com', {})
      expect(result.first).to eq(:pass)
    end

    it 'fails with invalid URL' do
      result = described_class.evaluate(:is_url, 'not a url at all', {})
      expect(result.first).to eq(:fail)
    end
  end

  describe ':is_email' do
    it 'passes with valid email' do
      result = described_class.evaluate(:is_email, 'test@example.com', {})
      expect(result.first).to eq(:pass)
    end

    it 'fails with invalid email' do
      result = described_class.evaluate(:is_email, 'not-an-email', {})
      expect(result.first).to eq(:fail)
    end
  end

  describe ':levenshtein' do
    it 'passes when edit distance is within threshold' do
      result = described_class.evaluate(:levenshtein, 'hallo', value: 'hello', max_distance: 2)
      expect(result.first).to eq(:pass)
      expect(result.last[:distance]).to eq(1)
    end

    it 'fails when edit distance exceeds threshold' do
      result = described_class.evaluate(:levenshtein, 'completely different', value: 'hello', max_distance: 1)
      expect(result.first).to eq(:fail)
      expect(result.last[:distance]).to be > 1
    end
  end
end
