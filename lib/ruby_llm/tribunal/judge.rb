# frozen_string_literal: true

module RubyLLM
  module Tribunal
    # Base module for LLM-as-judge assertions.
    #
    # All judges (built-in and custom) implement this interface. This provides
    # a consistent interface for evaluation criteria.
    #
    # @example Creating a custom judge
    #   class BrandVoiceJudge
    #     include RubyLLM::Tribunal::Judge
    #
    #     def self.judge_name
    #       :brand_voice
    #     end
    #
    #     def self.prompt(test_case, opts)
    #       <<~PROMPT
    #         Evaluate if the response matches our brand voice guidelines:
    #
    #         - Friendly but professional tone
    #         - No jargon or technical terms
    #         - Empathetic and helpful
    #
    #         Response to evaluate:
    #         #{test_case.actual_output}
    #
    #         Query: #{test_case.input}
    #       PROMPT
    #     end
    #   end
    #
    #   RubyLLM::Tribunal.register_judge(BrandVoiceJudge)
    module Judge
      # Built-in judge classes
      BUILTIN_JUDGES = [].freeze

      @custom_judges = []

      class << self
        attr_reader :custom_judges

        # Registers a custom judge class.
        #
        # @param judge_class [Class] A class implementing the Judge interface
        def register(judge_class)
          @custom_judges << judge_class unless @custom_judges.include?(judge_class)
        end

        # Returns all built-in judge modules.
        #
        # @return [Array<Class>] Built-in judge classes
        def builtin_judges
          [
            Judges::Faithful,
            Judges::Relevant,
            Judges::Hallucination,
            Judges::Correctness,
            Judges::Bias,
            Judges::Toxicity,
            Judges::Harmful,
            Judges::Jailbreak,
            Judges::PII,
            Judges::Refusal
          ]
        end

        # Returns all judge modules (built-in + custom).
        #
        # @return [Array<Class>] All judge classes
        def all_judges
          builtin_judges + @custom_judges
        end

        # Finds a judge module by name.
        #
        # @param name [Symbol] The judge name
        # @return [Class, nil] The judge class or nil
        def find(name)
          all_judges.find { |judge| judge.judge_name == name }
        end

        # Returns list of all judge names (built-in + custom).
        #
        # @return [Array<Symbol>] Judge names
        def all_judge_names
          all_judges.map(&:judge_name)
        end

        # Returns list of built-in judge names.
        #
        # @return [Array<Symbol>] Built-in judge names
        def builtin_judge_names
          builtin_judges.map(&:judge_name)
        end

        # Returns list of custom judge names.
        #
        # @return [Array<Symbol>] Custom judge names
        def custom_judge_names
          @custom_judges.map(&:judge_name)
        end

        # Checks if a name is a registered custom judge.
        #
        # @param name [Symbol] The judge name
        # @return [Boolean]
        def custom_judge?(name)
          custom_judge_names.include?(name)
        end

        # Checks if a name is a built-in judge.
        #
        # @param name [Symbol] The judge name
        # @return [Boolean]
        def builtin_judge?(name)
          builtin_judge_names.include?(name)
        end
      end

      # Interface methods that judge classes should implement

      # Returns the atom name for this judge.
      # This name is used to invoke the judge in assertions.
      #
      # @return [Symbol] The judge name
      def self.judge_name
        raise NotImplementedError, 'Judge classes must implement .judge_name'
      end

      # Builds the evaluation prompt for the LLM judge.
      #
      # @param test_case [TestCase] The test case
      # @param opts [Hash] Options
      # @return [String] The prompt
      def self.prompt(test_case, opts)
        raise NotImplementedError, 'Judge classes must implement .prompt(test_case, opts)'
      end

      # Optional: validate that the test case has required fields.
      #
      # @param _test_case [TestCase] The test case
      # @return [nil, String] nil if valid, error message if not
      def self.validate(_test_case)
        nil
      end

      # Optional: whether "no" verdict means pass (for negative metrics like toxicity).
      #
      # @return [Boolean]
      def self.negative_metric?
        false
      end

      # Optional: customize how the LLM result is interpreted.
      #
      # @param _result [Hash] The LLM response
      # @param _opts [Hash] Options
      # @return [Array] [:pass, details] or [:fail, details]
      def self.evaluate_result(_result, _opts)
        nil # Return nil to use default interpretation
      end
    end
  end
end
