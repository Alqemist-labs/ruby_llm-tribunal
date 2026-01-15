# frozen_string_literal: true

module RubyLLM
  module Tribunal
    # Helper methods for test framework integration.
    #
    # Include this module in your test classes to get access to assertion methods.
    #
    # @example With Minitest
    #   class MyEvalTest < Minitest::Test
    #     include RubyLLM::Tribunal::EvalHelpers
    #
    #     def test_response_is_faithful
    #       response = MyApp::RAG.query("What's the return policy?")
    #       assert_contains response, "30 days"
    #       assert_faithful response, context: @docs
    #     end
    #   end
    #
    # @example With RSpec
    #   RSpec.describe "RAG Evaluation" do
    #     include RubyLLM::Tribunal::EvalHelpers
    #
    #     it "response is faithful" do
    #       response = MyApp::RAG.query("What's the return policy?")
    #       expect_contains response, "30 days"
    #       expect_faithful response, context: docs
    #     end
    #   end
    module EvalHelpers
      # Deterministic assertions

      # Assert output contains substring(s)
      def assert_contains(output, value_or_opts)
        opts = normalize_opts(value_or_opts)
        result = Assertions::Deterministic.evaluate(:contains, output, opts)
        handle_result(result, 'contains')
      end

      # Assert output does not contain substring(s)
      def refute_contains(output, value_or_opts)
        opts = normalize_opts(value_or_opts)
        result = Assertions::Deterministic.evaluate(:not_contains, output, opts)
        handle_result(result, 'not_contains')
      end

      # Assert output contains at least one of the values
      def assert_contains_any(output, values)
        result = Assertions::Deterministic.evaluate(:contains_any, output, values:)
        handle_result(result, 'contains_any')
      end

      # Assert output contains all values
      def assert_contains_all(output, values)
        result = Assertions::Deterministic.evaluate(:contains_all, output, values:)
        handle_result(result, 'contains_all')
      end

      # Assert output matches regex pattern
      def assert_regex(output, pattern)
        result = Assertions::Deterministic.evaluate(:regex, output, pattern:)
        handle_result(result, 'regex')
      end

      # Assert output is valid JSON
      def assert_json(output)
        result = Assertions::Deterministic.evaluate(:is_json, output, {})
        handle_result(result, 'is_json')
      end

      # Assert output is under token limit
      def assert_max_tokens(output, max)
        result = Assertions::Deterministic.evaluate(:max_tokens, output, max:)
        handle_result(result, 'max_tokens')
      end

      # Assert output starts with prefix
      def assert_starts_with(output, prefix)
        result = Assertions::Deterministic.evaluate(:starts_with, output, value: prefix)
        handle_result(result, 'starts_with')
      end

      # Assert output ends with suffix
      def assert_ends_with(output, suffix)
        result = Assertions::Deterministic.evaluate(:ends_with, output, value: suffix)
        handle_result(result, 'ends_with')
      end

      # Assert output exactly equals expected
      def assert_equals(output, expected)
        result = Assertions::Deterministic.evaluate(:equals, output, value: expected)
        handle_result(result, 'equals')
      end

      # Assert output meets minimum length
      def assert_min_length(output, min)
        result = Assertions::Deterministic.evaluate(:min_length, output, min:)
        handle_result(result, 'min_length')
      end

      # Assert output under maximum length
      def assert_max_length(output, max)
        result = Assertions::Deterministic.evaluate(:max_length, output, max:)
        handle_result(result, 'max_length')
      end

      # Assert output word count within range
      def assert_word_count(output, opts)
        result = Assertions::Deterministic.evaluate(:word_count, output, opts)
        handle_result(result, 'word_count')
      end

      # Assert output is a valid URL
      def assert_url(output)
        result = Assertions::Deterministic.evaluate(:is_url, output, {})
        handle_result(result, 'is_url')
      end

      # Assert output is a valid email
      def assert_email(output)
        result = Assertions::Deterministic.evaluate(:is_email, output, {})
        handle_result(result, 'is_email')
      end

      # Assert output within Levenshtein distance of target
      def assert_levenshtein(output, target, opts = {})
        result = Assertions::Deterministic.evaluate(:levenshtein, output, opts.merge(value: target))
        handle_result(result, 'levenshtein')
      end

      # LLM-as-judge assertions

      # Assert response is faithful to context
      def assert_faithful(output, opts = {})
        test_case = build_test_case(output, opts)
        result = Assertions.evaluate(:faithful, test_case, opts)
        print_verbose(:faithful, result, opts)
        handle_result(result, 'faithful')
      end

      # Assert response is relevant to query
      def assert_relevant(output, opts = {})
        test_case = build_test_case(output, opts)
        result = Assertions.evaluate(:relevant, test_case, opts)
        print_verbose(:relevant, result, opts)
        handle_result(result, 'relevant')
      end

      # Assert response has no hallucinations
      def refute_hallucination(output, opts = {})
        test_case = build_test_case(output, opts)
        result = Assertions.evaluate(:hallucination, test_case, opts)
        print_verbose(:hallucination, result, opts)
        handle_result(result, 'hallucination')
      end

      # Assert response is correct compared to expected
      def assert_correctness(output, opts = {})
        test_case = build_test_case(output, opts)
        result = Assertions.evaluate(:correctness, test_case, opts)
        print_verbose(:correctness, result, opts)
        handle_result(result, 'correctness')
      end

      # Assert response has no bias
      def refute_bias(output, opts = {})
        test_case = build_test_case(output, opts)
        result = Assertions.evaluate(:bias, test_case, opts)
        print_verbose(:bias, result, opts)
        handle_result(result, 'bias')
      end

      # Assert response has no toxic content
      def refute_toxicity(output, opts = {})
        test_case = build_test_case(output, opts)
        result = Assertions.evaluate(:toxicity, test_case, opts)
        print_verbose(:toxicity, result, opts)
        handle_result(result, 'toxicity')
      end

      # Alias for refute_toxicity
      alias refute_toxic refute_toxicity

      # Assert response has no harmful content
      def refute_harmful(output, opts = {})
        test_case = build_test_case(output, opts)
        result = Assertions.evaluate(:harmful, test_case, opts)
        print_verbose(:harmful, result, opts)
        handle_result(result, 'harmful')
      end

      # Assert response shows no signs of jailbreak success
      def refute_jailbreak(output, opts = {})
        test_case = build_test_case(output, opts)
        result = Assertions.evaluate(:jailbreak, test_case, opts)
        print_verbose(:jailbreak, result, opts)
        handle_result(result, 'jailbreak')
      end

      # Assert response contains no PII
      def refute_pii(output, opts = {})
        test_case = build_test_case(output, opts)
        result = Assertions.evaluate(:pii, test_case, opts)
        print_verbose(:pii, result, opts)
        handle_result(result, 'pii')
      end

      # Assert output appears to be a refusal
      def assert_refusal(output, opts = {})
        test_case = build_test_case(output, opts)
        result = Assertions.evaluate(:refusal, test_case, opts)
        print_verbose(:refusal, result, opts)
        handle_result(result, 'refusal')
      end

      # Embedding-based assertions

      # Assert response is semantically similar to expected
      def assert_similar(output, opts = {})
        test_case = build_test_case(output, opts)
        result = Assertions.evaluate(:similar, test_case, opts)
        print_verbose(:similar, result, opts)
        handle_result(result, 'similar')
      end

      private

      def normalize_opts(value_or_opts)
        return value_or_opts if value_or_opts.is_a?(Hash)
        return { values: value_or_opts } if value_or_opts.is_a?(Array)

        { value: value_or_opts }
      end

      def build_test_case(output, opts)
        TestCase.new(
          actual_output: output,
          input: opts[:query] || opts[:input],
          context: opts[:context],
          expected_output: opts[:expected]
        )
      end

      def handle_result(result, assertion_type)
        case result
        in [:pass, _]
          true
        in [:fail, details]
          fail_assertion("#{assertion_type}: #{details[:reason]}")
        in [:error, message]
          fail_assertion("#{assertion_type} error: #{message}")
        end
      end

      def fail_assertion(message)
        # Try different test framework methods
        if respond_to?(:flunk)
          flunk(message)
        elsif respond_to?(:fail)
          raise(message)
        else
          raise AssertionError, message
        end
      end

      def print_verbose(assertion_type, result, opts)
        verbose = opts[:verbose] || Tribunal.configuration.verbose
        return unless verbose

        status, details = result
        return unless %i[pass fail].include?(status)

        puts format_verbose(status, assertion_type, details)
      end

      def format_verbose(status, type, details)
        icon = status == :pass ? '✓' : '✗'
        score_str = details[:score] ? " (score: #{details[:score].round(2)})" : ''
        verdict_str = details[:verdict] ? " [#{details[:verdict]}]" : ''

        "#{icon} #{type}#{score_str}#{verdict_str}: #{details[:reason]}"
      end

      # Custom error class for assertion failures
      class AssertionError < StandardError; end
    end
  end
end
