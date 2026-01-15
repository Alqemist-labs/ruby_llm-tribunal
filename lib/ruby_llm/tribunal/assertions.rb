# frozen_string_literal: true

module RubyLLM
  module Tribunal
    # Assertion evaluation engine.
    #
    # Routes assertions to the appropriate implementation:
    # - Deterministic: `contains`, `regex`, `is_json`, etc.
    # - Judge (requires ruby_llm): `faithful`, `relevant`, etc.
    # - Embedding (requires neighbor): `similar`
    module Assertions
      DETERMINISTIC_ASSERTIONS = %i[
        contains
        not_contains
        contains_any
        contains_all
        regex
        is_json
        max_tokens
        latency_ms
        starts_with
        ends_with
        equals
        min_length
        max_length
        word_count
        is_url
        is_email
        levenshtein
      ].freeze

      EMBEDDING_ASSERTIONS = %i[similar].freeze

      class << self
        # Evaluates a single assertion against a test case.
        #
        # @param assertion_type [Symbol] The type of assertion
        # @param test_case [TestCase] The test case to evaluate
        # @param opts [Hash] Options for the assertion
        # @return [Array] [:pass, details] or [:fail, details]
        def evaluate(assertion_type, test_case, opts = {})
          if DETERMINISTIC_ASSERTIONS.include?(assertion_type)
            Deterministic.evaluate(assertion_type, test_case.actual_output, opts)
          elsif Tribunal::Judge.builtin_judge?(assertion_type) || Tribunal::Judge.custom_judge?(assertion_type)
            evaluate_judge(assertion_type, test_case, opts)
          elsif EMBEDDING_ASSERTIONS.include?(assertion_type)
            evaluate_embedding(assertion_type, test_case, opts)
          else
            [:error, "Unknown assertion type: #{assertion_type}"]
          end
        end

        # Evaluates multiple assertions against a test case.
        #
        # @param assertions [Array, Hash] Assertions to evaluate
        # @param test_case [TestCase] The test case to evaluate
        # @return [Hash] Map of assertion_type => result
        def evaluate_all(assertions, test_case)
          normalized = normalize_assertions(assertions)
          normalized.each_with_object({}) do |(type, opts), results|
            results[type] = evaluate(type, test_case, opts)
          end
        end

        # Checks if all assertions passed.
        #
        # @param results [Hash] Results from evaluate_all
        # @return [Boolean] True if all passed
        def all_passed?(results)
          results.all? { |_type, result| result.first == :pass }
        end

        # Returns list of available assertion types based on loaded dependencies.
        #
        # @return [Array<Symbol>] Available assertion types
        def available
          base = DETERMINISTIC_ASSERTIONS.dup

          # Add judge assertions
          base.concat(Tribunal::Judge.all_judge_names)

          # Add embedding assertions if neighbor is available
          begin
            require 'neighbor'
            base.concat(EMBEDDING_ASSERTIONS)
          rescue LoadError
            # neighbor not available
          end

          base
        end

        private

        def normalize_assertions(assertions)
          case assertions
          when Hash
            assertions.map do |type, opts|
              opts = { value: opts } unless opts.is_a?(Hash)
              [type.to_sym, opts]
            end
          when Array
            assertions.map do |item|
              case item
              when Symbol, String
                [item.to_sym, {}]
              when Array
                type, opts = item
                opts = { value: opts } unless opts.is_a?(Hash)
                [type.to_sym, opts]
              else
                raise ArgumentError, "Invalid assertion format: #{item.inspect}"
              end
            end
          else
            raise ArgumentError, 'Assertions must be a Hash or Array'
          end
        end

        def evaluate_judge(type, test_case, opts)
          Assertions::Judge.evaluate(type, test_case, opts)
        end

        def evaluate_embedding(_type, test_case, opts)
          begin
            require 'neighbor'
          rescue LoadError
            raise Error, <<~MSG
              Embedding similarity requires the 'neighbor' gem.

              Add to your Gemfile:
                gem 'neighbor', '~> 0.4'
            MSG
          end

          Embedding.evaluate(test_case, opts)
        end
      end
    end
  end
end
