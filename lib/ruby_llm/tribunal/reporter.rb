# frozen_string_literal: true

module RubyLLM
  module Tribunal
    # Base module for eval result reporters.
    #
    # Results structure:
    #   {
    #     summary: {
    #       total: Integer,
    #       passed: Integer,
    #       failed: Integer,
    #       pass_rate: Float,
    #       duration_ms: Integer
    #     },
    #     metrics: { Symbol => { passed: Integer, total: Integer } },
    #     cases: [{ input:, status:, failures:, results:, duration_ms: }]
    #   }
    module Reporter
      # Formats results using the specified reporter.
      #
      # @param results [Hash] Evaluation results
      # @param format [String, Symbol] Output format
      # @return [String] Formatted output
      def self.format(results, format = :console)
        reporter_class = case format.to_sym
                         when :console then Reporters::Console
                         when :text then Reporters::Text
                         when :json then Reporters::JSON
                         when :html then Reporters::HTML
                         when :github then Reporters::GitHub
                         when :junit then Reporters::JUnit
                         else
                           raise ArgumentError, "Unknown format: #{format}"
                         end

        reporter_class.format(results)
      end

      # Available reporter formats.
      #
      # @return [Array<Symbol>]
      def self.available_formats
        %i[console text json html github junit]
      end
    end
  end
end
