# frozen_string_literal: true

RSpec.describe RubyLLM::Tribunal::TestCase do
  describe '#initialize' do
    it 'creates a test case from a hash with symbol keys' do
      test_case = described_class.new(
        input: "What's the return policy?",
        actual_output: 'You can return items within 30 days.',
        context: ['Returns accepted within 30 days with receipt.'],
        expected_output: 'Items can be returned within 30 days with a receipt.'
      )

      expect(test_case.input).to eq("What's the return policy?")
      expect(test_case.actual_output).to eq('You can return items within 30 days.')
      expect(test_case.context).to eq(['Returns accepted within 30 days with receipt.'])
      expect(test_case.expected_output).to eq('Items can be returned within 30 days with a receipt.')
    end

    it 'creates a test case from a hash with string keys' do
      test_case = described_class.new(
        'input' => 'Hello',
        'actual_output' => 'Hi!'
      )

      expect(test_case.input).to eq('Hello')
      expect(test_case.actual_output).to eq('Hi!')
    end

    it 'normalizes context to array' do
      test_case = described_class.new(
        input: 'test',
        context: 'Single context string'
      )

      expect(test_case.context).to eq(['Single context string'])
    end
  end

  describe '#with_output' do
    it 'returns a new test case with the output set' do
      original = described_class.new(input: 'test')
      with_output = original.with_output('response')

      expect(original.actual_output).to be_nil
      expect(with_output.actual_output).to eq('response')
      expect(with_output.input).to eq('test')
    end
  end

  describe '#with_retrieval_context' do
    it 'returns a new test case with retrieval context set' do
      original = described_class.new(input: 'test')
      with_context = original.with_retrieval_context(%w[doc1 doc2])

      expect(original.retrieval_context).to be_nil
      expect(with_context.retrieval_context).to eq(%w[doc1 doc2])
    end
  end

  describe '#with_metadata' do
    it 'returns a new test case with merged metadata' do
      original = described_class.new(input: 'test', metadata: { latency: 100 })
      with_meta = original.with_metadata(tokens: 50)

      expect(with_meta.metadata).to eq({ latency: 100, tokens: 50 })
    end
  end

  describe '#to_h' do
    it 'converts the test case to a hash' do
      test_case = described_class.new(
        input: 'test',
        actual_output: 'response'
      )

      hash = test_case.to_h

      expect(hash[:input]).to eq('test')
      expect(hash[:actual_output]).to eq('response')
      expect(hash).not_to have_key(:context)
    end
  end
end
