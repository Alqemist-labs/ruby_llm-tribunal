# frozen_string_literal: true

require 'ruby_llm'
require 'json'
require 'yaml'

require_relative 'tribunal/version'
require_relative 'tribunal/configuration'
require_relative 'tribunal/test_case'
require_relative 'tribunal/assertions'
require_relative 'tribunal/assertions/deterministic'
require_relative 'tribunal/assertions/judge'
require_relative 'tribunal/assertions/embedding'
require_relative 'tribunal/judge'
require_relative 'tribunal/judges/faithful'
require_relative 'tribunal/judges/relevant'
require_relative 'tribunal/judges/hallucination'
require_relative 'tribunal/judges/correctness'
require_relative 'tribunal/judges/bias'
require_relative 'tribunal/judges/toxicity'
require_relative 'tribunal/judges/harmful'
require_relative 'tribunal/judges/jailbreak'
require_relative 'tribunal/judges/pii'
require_relative 'tribunal/judges/refusal'
require_relative 'tribunal/dataset'
require_relative 'tribunal/red_team'
require_relative 'tribunal/reporter'
require_relative 'tribunal/reporters/console'
require_relative 'tribunal/reporters/text'
require_relative 'tribunal/reporters/json'
require_relative 'tribunal/reporters/html'
require_relative 'tribunal/reporters/github'
require_relative 'tribunal/reporters/junit'
require_relative 'tribunal/eval_helpers'

module RubyLLM
  # LLM evaluation framework for Ruby.
  #
  # Tribunal provides tools for evaluating LLM outputs,
  # detecting hallucinations, and measuring response quality.
  #
  # @example Quick Start
  #   test_case = RubyLLM::Tribunal.test_case(
  #     input: "What's the return policy?",
  #     actual_output: "Returns within 30 days.",
  #     context: ["Return policy: 30 days with receipt."]
  #   )
  #
  #   assertions = [
  #     [:contains, { value: "30 days" }],
  #     [:faithful, { threshold: 0.8 }]
  #   ]
  #
  #   results = RubyLLM::Tribunal.evaluate(test_case, assertions)
  #
  module Tribunal
    class Error < StandardError; end

    class << self
      # Configuration for Tribunal
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end

      # Evaluates a test case against assertions.
      #
      # @param test_case [TestCase] The test case to evaluate
      # @param assertions [Array, Hash] Assertions to run
      # @return [Hash] Results map of assertion_type => result
      #
      # @example
      #   test_case = TestCase.new(
      #     input: "What's the return policy?",
      #     actual_output: "Returns within 30 days.",
      #     context: ["Return policy: 30 days with receipt."]
      #   )
      #
      #   assertions = [
      #     [:contains, { value: "30 days" }],
      #     [:faithful, { threshold: 0.8 }]
      #   ]
      #
      #   Tribunal.evaluate(test_case, assertions)
      #   #=> { contains: [:pass, {...}], faithful: [:pass, {...}] }
      def evaluate(test_case, assertions)
        Assertions.evaluate_all(assertions, test_case)
      end

      # Returns available assertion types based on loaded dependencies.
      #
      # @return [Array<Symbol>] List of available assertion types
      def available_assertions
        Assertions.available
      end

      # Creates a new test case.
      #
      # @param attrs [Hash] Test case attributes
      # @return [TestCase] New test case instance
      #
      # @example
      #   Tribunal.test_case(
      #     input: "What's the price?",
      #     actual_output: "The price is $29.99.",
      #     context: ["Product costs $29.99"]
      #   )
      def test_case(attrs)
        TestCase.new(attrs)
      end

      # Registers a custom judge.
      #
      # @param judge_class [Class] A class implementing the Judge interface
      def register_judge(judge_class)
        Judge.register(judge_class)
      end

      # Returns all registered judge names.
      #
      # @return [Array<Symbol>] List of judge names
      def judge_names
        Judge.all_judge_names
      end
    end
  end
end
