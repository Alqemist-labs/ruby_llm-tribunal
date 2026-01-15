# frozen_string_literal: true

module RubyLLM
  module Tribunal
    # Represents a single evaluation test case.
    #
    # @attr_reader input [String] The user query/prompt (required)
    # @attr_reader actual_output [String, nil] The LLM response to evaluate
    # @attr_reader expected_output [String, nil] Golden/ideal answer for comparison
    # @attr_reader context [Array<String>, nil] Ground truth context for faithfulness checks
    # @attr_reader retrieval_context [Array<String>, nil] Actual retrieved docs from RAG
    # @attr_reader metadata [Hash, nil] Additional info like latency, tokens, cost
    #
    # @example
    #   test_case = TestCase.new(
    #     input: "What's the return policy?",
    #     actual_output: "You can return items within 30 days.",
    #     context: ["Returns accepted within 30 days with receipt."],
    #     expected_output: "Items can be returned within 30 days with a receipt."
    #   )
    class TestCase
      attr_reader :input, :actual_output, :expected_output, :context, :retrieval_context, :metadata

      # Creates a new test case from a hash.
      #
      # @param attrs [Hash] Test case attributes
      # @option attrs [String] :input The user query/prompt
      # @option attrs [String] :actual_output The LLM response to evaluate
      # @option attrs [String] :expected_output Golden/ideal answer
      # @option attrs [Array<String>, String] :context Ground truth context
      # @option attrs [Array<String>] :retrieval_context Retrieved docs from RAG
      # @option attrs [Hash] :metadata Additional info
      def initialize(attrs = {})
        attrs = normalize_keys(attrs)

        @input = attrs[:input]
        @actual_output = attrs[:actual_output]
        @expected_output = attrs[:expected_output]
        @context = normalize_context(attrs[:context])
        @retrieval_context = normalize_context(attrs[:retrieval_context])
        @metadata = attrs[:metadata]
      end

      # Sets the actual output on an existing test case.
      # Useful when the dataset provides input/context but output comes from your LLM.
      #
      # @param output [String] The LLM response
      # @return [TestCase] A new test case with the output set
      def with_output(output)
        TestCase.new(
          input: @input,
          actual_output: output,
          expected_output: @expected_output,
          context: @context,
          retrieval_context: @retrieval_context,
          metadata: @metadata
        )
      end

      # Sets the retrieval context from your RAG pipeline.
      #
      # @param context [Array<String>, String] Retrieved documents
      # @return [TestCase] A new test case with retrieval context set
      def with_retrieval_context(context)
        TestCase.new(
          input: @input,
          actual_output: @actual_output,
          expected_output: @expected_output,
          context: @context,
          retrieval_context: normalize_context(context),
          metadata: @metadata
        )
      end

      # Adds metadata (latency, tokens, cost, etc).
      #
      # @param new_metadata [Hash] Metadata to merge
      # @return [TestCase] A new test case with merged metadata
      def with_metadata(new_metadata)
        merged = (@metadata || {}).merge(new_metadata)
        TestCase.new(
          input: @input,
          actual_output: @actual_output,
          expected_output: @expected_output,
          context: @context,
          retrieval_context: @retrieval_context,
          metadata: merged
        )
      end

      # Converts the test case to a hash.
      #
      # @return [Hash] Test case as hash
      def to_h
        {
          input: @input,
          actual_output: @actual_output,
          expected_output: @expected_output,
          context: @context,
          retrieval_context: @retrieval_context,
          metadata: @metadata
        }.compact
      end

      private

      def normalize_keys(hash)
        hash.transform_keys do |key|
          case key
          when String then key.to_sym
          else key
          end
        end
      end

      def normalize_context(ctx)
        return nil if ctx.nil?
        return [ctx] if ctx.is_a?(String)

        ctx
      end
    end
  end
end
