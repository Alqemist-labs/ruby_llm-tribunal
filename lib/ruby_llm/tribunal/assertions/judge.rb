# frozen_string_literal: true

module RubyLLM
  module Tribunal
    module Assertions
      # LLM-as-judge assertions for evaluating LLM outputs.
      #
      # Uses RubyLLM to get structured verdicts from the judge model.
      module Judge
        DEFAULT_MODEL = 'anthropic:claude-3-5-haiku-latest'
        DEFAULT_THRESHOLD = 0.8

        SYSTEM_PROMPT = <<~PROMPT
          You are a precise evaluator of LLM outputs. Your task is to assess outputs
          based on specific criteria and provide structured verdicts.

          Always respond with valid JSON containing:
          - verdict: "yes", "no", or "partial"
          - reason: A brief explanation
          - score: A float from 0.0 to 1.0

          Be objective and consistent in your evaluations.
        PROMPT

        class << self
          # Returns list of available judge assertion types.
          #
          # @return [Array<Symbol>]
          def available
            Tribunal::Judge.all_judge_names
          end

          # Evaluates a judge assertion against a test case.
          #
          # @param type [Symbol] The judge type
          # @param test_case [TestCase] The test case
          # @param opts [Hash] Options
          # @return [Array] [:pass, details], [:fail, details], or [:error, message]
          def evaluate(type, test_case, opts)
            judge_class = Tribunal::Judge.find(type)
            return [:error, "Unknown judge assertion: #{type}"] unless judge_class

            # Validate test case
            error = judge_class.validate(test_case) if judge_class.respond_to?(:validate)
            return [:error, error] if error

            run_judge(judge_class, test_case, opts)
          end

          private

          def run_judge(judge_class, test_case, opts)
            model = opts[:model] || Tribunal.configuration.default_model || DEFAULT_MODEL
            threshold = opts[:threshold] || Tribunal.configuration.default_threshold || DEFAULT_THRESHOLD
            prompt = judge_class.prompt(test_case, opts)

            response = call_llm(model, prompt, opts)

            case response
            in [:ok, result]
              # Check if judge has custom evaluation
              if judge_class.respond_to?(:evaluate_result)
                custom_result = judge_class.evaluate_result(result, opts)
                return custom_result if custom_result
              end

              negative_metric = judge_class.respond_to?(:negative_metric?) && judge_class.negative_metric?
              interpret_response(result, threshold, negative_metric)
            in [:error, reason]
              [:error, reason.to_s]
            end
          end

          def call_llm(model, prompt, opts)
            # Allow injecting custom LLM for tests via opts[:llm]
            return opts[:llm].call(model, build_messages(prompt), opts) if opts[:llm]

            call_ruby_llm(model, prompt, opts)
          end

          def build_messages(prompt)
            [
              { role: 'system', content: SYSTEM_PROMPT },
              { role: 'user', content: prompt }
            ]
          end

          def call_ruby_llm(model, prompt, _opts)
            # Parse model string (e.g., "anthropic:claude-3-5-haiku-latest")
            _provider, model_name = parse_model(model)

            chat = RubyLLM.chat(model: model_name)

            # Add system message
            chat.with_instructions(SYSTEM_PROMPT)

            # Get response
            response = chat.ask(prompt)
            content = response.content

            # Parse JSON response
            parsed = JSON.parse(content)
            [:ok, parsed]
          rescue JSON::ParserError => e
            # Try to extract JSON from response
            if (match = content&.match(/\{[\s\S]*\}/))
              begin
                parsed = JSON.parse(match[0])
                return [:ok, parsed]
              rescue JSON::ParserError
                # Fall through to error
              end
            end
            [:error, "Failed to parse LLM response as JSON: #{e.message}"]
          rescue StandardError => e
            [:error, e.message]
          end

          def parse_model(model_string)
            if model_string.include?(':')
              model_string.split(':', 2)
            else
              [nil, model_string]
            end
          end

          def interpret_response(response, threshold, negative_metric)
            details = {
              verdict: response['verdict'],
              reason: response['reason'],
              score: response['score']
            }

            verdict_result(response['verdict'], response['score'], threshold, negative_metric, details)
          end

          def verdict_result(verdict, score, threshold, negative_metric, details)
            return [:error, "Unexpected verdict: #{verdict}"] unless %w[yes no partial].include?(verdict)

            passed = case verdict
                     when 'yes' then !negative_metric
                     when 'no' then negative_metric
                     when 'partial' then score.is_a?(Numeric) && score >= threshold
                     end

            passed ? [:pass, details] : [:fail, details]
          end
        end
      end
    end
  end
end
