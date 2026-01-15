# frozen_string_literal: true

module RubyLLM
  module Tribunal
    module Assertions
      # Embedding-based semantic similarity assertions.
      #
      # Uses sentence embeddings to determine if two texts are semantically similar.
      module Embedding
        DEFAULT_THRESHOLD = 0.7

        class << self
          # Returns list of available embedding assertion types.
          #
          # @return [Array<Symbol>]
          def available
            [:similar]
          end

          # Evaluates semantic similarity between actual and expected output.
          #
          # @param test_case [TestCase] The test case
          # @param opts [Hash] Options
          # @option opts [Float] :threshold Similarity threshold (0.0 to 1.0). Default: 0.7
          # @option opts [Proc] :similarity_fn Custom similarity function for testing
          # @return [Array] [:pass, details], [:fail, details], or [:error, message]
          #
          # @example
          #   test_case = TestCase.new(
          #     actual_output: "The cat is sleeping",
          #     expected_output: "A feline is resting"
          #   )
          #
          #   Embedding.evaluate(test_case, threshold: 0.8)
          #   #=> [:pass, { similarity: 0.85, threshold: 0.8 }]
          def evaluate(test_case, opts = {})
            if test_case.expected_output.nil?
              return [:error,
                      'Similar assertion requires expected_output to be provided']
            end

            threshold = opts[:threshold] || DEFAULT_THRESHOLD
            similarity_fn = opts[:similarity_fn] || method(:default_similarity)

            result = similarity_fn.call(test_case.actual_output, test_case.expected_output, opts)

            case result
            in [:ok, similarity] if similarity >= threshold
              [:pass, { similarity:, threshold: }]
            in [:ok, similarity]
              [:fail, {
                similarity:,
                threshold:,
                reason: "Output is not semantically similar to expected (#{similarity.round(2)} < #{threshold})"
              }]
            in [:error, reason]
              [:error, "Failed to compute similarity: #{reason}"]
            end
          end

          private

          def default_similarity(text1, text2, opts)
            # Use RubyLLM embeddings
            model = opts[:embedding_model] || 'text-embedding-3-small'

            embedding1 = RubyLLM.embed(text1, model:).vectors.first
            embedding2 = RubyLLM.embed(text2, model:).vectors.first

            # Compute cosine similarity
            similarity = cosine_similarity(embedding1, embedding2)
            [:ok, similarity]
          rescue StandardError => e
            [:error, e.message]
          end

          def cosine_similarity(vec1, vec2)
            dot_product = vec1.zip(vec2).sum { |a, b| a * b }
            magnitude1 = Math.sqrt(vec1.sum { |x| x**2 })
            magnitude2 = Math.sqrt(vec2.sum { |x| x**2 })

            return 0.0 if magnitude1.zero? || magnitude2.zero?

            dot_product / (magnitude1 * magnitude2)
          end
        end
      end
    end
  end
end
