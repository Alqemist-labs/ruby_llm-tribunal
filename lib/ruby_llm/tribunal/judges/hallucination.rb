# frozen_string_literal: true

module RubyLLM
  module Tribunal
    module Judges
      # Detects claims not supported by the provided context.
      #
      # A hallucination is information that is not present in or supported by the context.
      # This is a negative metric: "yes" (hallucination detected) = fail.
      #
      # Uses claim extraction approach: identifies factual claims, verifies each
      # against context, flags unsupported or contradicted claims.
      class Hallucination
        class << self
          def judge_name
            :hallucination
          end

          def negative_metric?
            true
          end

          def validate(test_case)
            return unless test_case.context.nil? || test_case.context.empty?

            'Hallucination assertion requires context to be provided'
          end

          def prompt(test_case, _opts)
            context = format_context(test_case.context)

            <<~PROMPT
              You are evaluating whether an LLM output contains hallucinations.
              A hallucination is a factual claim that cannot be verified from the provided context.

              ## Context
              #{context}

              ## Question
              #{test_case.input}

              ## Output to Evaluate
              #{test_case.actual_output}

              ## Evaluation Process
              1. Extract each factual claim from the output (skip opinions, hedged statements)
              2. For each claim, check if it can be inferred from the context
              3. Identify any claims that are unsupported or contradict the context

              ## Hallucination Types
              - **Fabrication**: Inventing facts not present in context (e.g., dates, names, numbers)
              - **Contradiction**: Stating something that conflicts with the context
              - **Extrapolation**: Drawing conclusions the context doesn't support
              - **Conflation**: Mixing up entities or attributes from the context

              ## NOT Hallucinations
              - Paraphrasing or summarizing context accurately
              - Common knowledge that doesn't conflict with context
              - Hedged language ("might be", "possibly", "it seems")
              - Logical inferences clearly supported by context

              ## Response Format
              Respond with JSON:
              - verdict: "yes" if any hallucination detected, "no" if all claims are supported
              - reason: List each hallucinated claim and explain why it's unsupported
              - score: 0.0 (no hallucination) to 1.0 (severe/multiple hallucinations)
            PROMPT
          end

          private

          def format_context(context)
            return '(no context provided)' if context.nil? || context.empty?

            if context.is_a?(Array)
              context.each_with_index.map { |item, idx| "#{idx + 1}. #{item}" }.join("\n")
            else
              context.to_s
            end
          end
        end
      end
    end
  end
end
