# frozen_string_literal: true

RSpec.describe RubyLLM::Tribunal::Assertions::Judge do
  let(:mock_client) do
    ->(response) { ->(_model, _messages, _opts) { response } }
  end

  describe '.evaluate' do
    context 'with faithful assertion' do
      it 'returns pass when output is faithful to context' do
        test_case = RubyLLM::Tribunal::TestCase.new(
          input: 'What is the return policy?',
          actual_output: 'You can return items within 30 days with a receipt.',
          context: ['Returns are accepted within 30 days of purchase with a valid receipt.']
        )

        client = mock_client.call([:ok, {
                                    'verdict' => 'yes',
                                    'reason' => 'Output accurately reflects the context about 30-day returns with receipt.',
                                    'score' => 1.0
                                  }])

        result = described_class.evaluate(:faithful, test_case, llm: client)

        expect(result.first).to eq(:pass)
        expect(result.last[:verdict]).to eq('yes')
      end

      it 'returns fail when output contradicts context' do
        test_case = RubyLLM::Tribunal::TestCase.new(
          input: 'What is the return policy?',
          actual_output: 'You can return items anytime, no questions asked.',
          context: ['Returns are accepted within 30 days of purchase with a valid receipt.']
        )

        client = mock_client.call([:ok, {
                                    'verdict' => 'no',
                                    'reason' => 'Output claims unlimited returns but context specifies 30-day limit.',
                                    'score' => 0.2
                                  }])

        result = described_class.evaluate(:faithful, test_case, llm: client)

        expect(result.first).to eq(:fail)
        expect(result.last[:verdict]).to eq('no')
      end

      it 'requires context' do
        test_case = RubyLLM::Tribunal::TestCase.new(
          input: 'What is the return policy?',
          actual_output: 'You can return items within 30 days.'
        )

        result = described_class.evaluate(:faithful, test_case, {})

        expect(result.first).to eq(:error)
        expect(result.last).to include('context')
      end
    end

    context 'with relevant assertion' do
      it 'returns pass when output answers the question' do
        test_case = RubyLLM::Tribunal::TestCase.new(
          input: 'What are the store hours?',
          actual_output: 'We are open Monday through Friday from 9am to 5pm.'
        )

        client = mock_client.call([:ok, {
                                    'verdict' => 'yes',
                                    'reason' => 'Output directly answers the question about store hours.',
                                    'score' => 1.0
                                  }])

        result = described_class.evaluate(:relevant, test_case, llm: client)

        expect(result.first).to eq(:pass)
      end

      it 'returns fail when output is off-topic' do
        test_case = RubyLLM::Tribunal::TestCase.new(
          input: 'What are the store hours?',
          actual_output: 'We have the best prices in town!'
        )

        client = mock_client.call([:ok, {
                                    'verdict' => 'no',
                                    'reason' => "Output discusses prices but doesn't answer the question about store hours.",
                                    'score' => 0.1
                                  }])

        result = described_class.evaluate(:relevant, test_case, llm: client)

        expect(result.first).to eq(:fail)
      end
    end

    context 'with hallucination assertion (negative metric)' do
      it 'returns pass when no hallucination detected' do
        test_case = RubyLLM::Tribunal::TestCase.new(
          input: 'What is the capital of France?',
          actual_output: 'The capital of France is Paris.',
          context: ['France is a country in Western Europe. Its capital city is Paris.']
        )

        client = mock_client.call([:ok, {
                                    'verdict' => 'no',
                                    'reason' => 'All claims in the output are supported by the context.',
                                    'score' => 0.0
                                  }])

        # For hallucination, "no" means no hallucination = pass
        result = described_class.evaluate(:hallucination, test_case, llm: client)

        expect(result.first).to eq(:pass)
        expect(result.last[:verdict]).to eq('no')
      end

      it 'returns fail when hallucination detected' do
        test_case = RubyLLM::Tribunal::TestCase.new(
          input: 'What is the capital of France?',
          actual_output: 'The capital of France is Paris, which was founded in 250 BC.',
          context: ['France is a country in Western Europe. Its capital city is Paris.']
        )

        client = mock_client.call([:ok, {
                                    'verdict' => 'yes',
                                    'reason' => 'The founding date of 250 BC is not mentioned in the context.',
                                    'score' => 0.8
                                  }])

        # For hallucination, "yes" means hallucination detected = fail
        result = described_class.evaluate(:hallucination, test_case, llm: client)

        expect(result.first).to eq(:fail)
        expect(result.last[:verdict]).to eq('yes')
      end
    end

    context 'with correctness assertion' do
      it 'returns pass when output matches expected' do
        test_case = RubyLLM::Tribunal::TestCase.new(
          input: 'What is 2 + 2?',
          actual_output: 'The answer is 4.',
          expected_output: '4'
        )

        client = mock_client.call([:ok, {
                                    'verdict' => 'yes',
                                    'reason' => 'Output correctly states the answer is 4.',
                                    'score' => 1.0
                                  }])

        result = described_class.evaluate(:correctness, test_case, llm: client)

        expect(result.first).to eq(:pass)
      end

      it 'requires expected_output' do
        test_case = RubyLLM::Tribunal::TestCase.new(
          input: 'What is 2 + 2?',
          actual_output: 'The answer is 4.'
        )

        result = described_class.evaluate(:correctness, test_case, {})

        expect(result.first).to eq(:error)
        expect(result.last).to include('expected')
      end
    end

    context 'with threshold option' do
      it 'uses threshold for partial verdicts' do
        test_case = RubyLLM::Tribunal::TestCase.new(
          input: 'Test',
          actual_output: 'Output',
          context: ['Context']
        )

        client = mock_client.call([:ok, {
                                    'verdict' => 'partial',
                                    'score' => 0.7,
                                    'reason' => 'Partially faithful'
                                  }])

        # With default threshold (0.8), should fail
        result = described_class.evaluate(:faithful, test_case, llm: client)
        expect(result.first).to eq(:fail)

        # With lower threshold, should pass
        result = described_class.evaluate(:faithful, test_case, threshold: 0.6, llm: client)
        expect(result.first).to eq(:pass)
      end
    end

    context 'with partial verdict on negative metrics' do
      it 'inverts threshold logic for negative metrics like toxicity' do
        test_case = RubyLLM::Tribunal::TestCase.new(
          input: 'Test',
          actual_output: 'Output'
        )

        # High score (0.9) on toxicity = very toxic = should FAIL
        client_high_score = mock_client.call([:ok, {
                                               'verdict' => 'partial',
                                               'score' => 0.9,
                                               'reason' => 'Highly toxic content'
                                             }])

        result = described_class.evaluate(:toxicity, test_case, threshold: 0.8, llm: client_high_score)
        expect(result.first).to eq(:fail)

        # Low score (0.1) on toxicity = not toxic = should PASS
        client_low_score = mock_client.call([:ok, {
                                              'verdict' => 'partial',
                                              'score' => 0.1,
                                              'reason' => 'Minor concerns'
                                            }])

        result = described_class.evaluate(:toxicity, test_case, threshold: 0.8, llm: client_low_score)
        expect(result.first).to eq(:pass)
      end

      it 'inverts threshold logic for hallucination metric' do
        test_case = RubyLLM::Tribunal::TestCase.new(
          input: 'Test',
          actual_output: 'Output',
          context: ['Context']
        )

        # High score (0.8) on hallucination = severe hallucination = should FAIL
        client_high_score = mock_client.call([:ok, {
                                               'verdict' => 'partial',
                                               'score' => 0.8,
                                               'reason' => 'Significant hallucination'
                                             }])

        result = described_class.evaluate(:hallucination, test_case, threshold: 0.8, llm: client_high_score)
        expect(result.first).to eq(:fail)

        # Low score (0.15) on hallucination = minimal = should PASS with threshold 0.8
        # (passes if score <= 1.0 - 0.8 = 0.2)
        client_low_score = mock_client.call([:ok, {
                                              'verdict' => 'partial',
                                              'score' => 0.15,
                                              'reason' => 'Minor inaccuracy'
                                            }])

        result = described_class.evaluate(:hallucination, test_case, threshold: 0.8, llm: client_low_score)
        expect(result.first).to eq(:pass)
      end

      it 'handles edge case at threshold boundary for negative metrics' do
        test_case = RubyLLM::Tribunal::TestCase.new(
          input: 'Test',
          actual_output: 'Output'
        )

        # Score below boundary should pass
        # For negative metrics: pass if score <= (1.0 - threshold)
        # With threshold 0.8: pass if score <= ~0.2
        client_below = mock_client.call([:ok, {
                                          'verdict' => 'partial',
                                          'score' => 0.19,
                                          'reason' => 'Below boundary'
                                        }])

        result = described_class.evaluate(:toxicity, test_case, threshold: 0.8, llm: client_below)
        expect(result.first).to eq(:pass)

        # Score above boundary (0.25 with threshold 0.8) should fail
        client_above = mock_client.call([:ok, {
                                          'verdict' => 'partial',
                                          'score' => 0.25,
                                          'reason' => 'Above boundary'
                                        }])

        result = described_class.evaluate(:toxicity, test_case, threshold: 0.8, llm: client_above)
        expect(result.first).to eq(:fail)
      end

      it 'handles partial verdict with non-numeric score' do
        test_case = RubyLLM::Tribunal::TestCase.new(
          input: 'Test',
          actual_output: 'Output'
        )

        client = mock_client.call([:ok, {
                                    'verdict' => 'partial',
                                    'score' => nil,
                                    'reason' => 'No score provided'
                                  }])

        result = described_class.evaluate(:toxicity, test_case, llm: client)
        expect(result.first).to eq(:fail)
      end
    end

    context 'with LLM errors' do
      it 'handles errors gracefully' do
        test_case = RubyLLM::Tribunal::TestCase.new(
          input: 'Test',
          actual_output: 'Output'
        )

        client = mock_client.call([:error, 'API rate limit exceeded'])

        result = described_class.evaluate(:relevant, test_case, llm: client)

        expect(result.first).to eq(:error)
        expect(result.last).to include('rate limit')
      end
    end
  end

  describe '.available' do
    it 'returns list of judge assertions' do
      available = described_class.available

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
end
