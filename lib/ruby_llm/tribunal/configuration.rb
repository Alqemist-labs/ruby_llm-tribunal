# frozen_string_literal: true

module RubyLLM
  module Tribunal
    # Configuration for Tribunal.
    #
    # @example
    #   RubyLLM::Tribunal.configure do |config|
    #     config.default_model = "anthropic:claude-3-5-haiku-latest"
    #     config.default_threshold = 0.8
    #     config.verbose = true
    #   end
    class Configuration
      # Default LLM model for judge assertions
      # @return [String]
      attr_accessor :default_model

      # Default threshold for judge assertions (0.0-1.0)
      # @return [Float]
      attr_accessor :default_threshold

      # Whether to print verbose output
      # @return [Boolean]
      attr_accessor :verbose

      # Custom judges to register
      # @return [Array<Class>]
      attr_accessor :custom_judges

      def initialize
        @default_model = 'anthropic:claude-3-5-haiku-latest'
        @default_threshold = 0.8
        @verbose = false
        @custom_judges = []
      end
    end
  end
end
