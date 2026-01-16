# frozen_string_literal: true

module RubyLLM
  module Tribunal
    module Reporters
      # GitHub Actions annotations format.
      class GitHub
        class << self
          def format(results)
            failed_cases = results[:cases].select { |c| c[:status] == :failed }
            annotations = failed_cases.map do |c|
              reasons = c[:failures].map { |type, reason| "#{type}: #{reason}" }.join('; ')
              "::error::#{c[:input]}: #{reasons}"
            end

            summary = "::notice::Tribunal: #{results[:summary][:passed]}/#{results[:summary][:total]} passed " \
                      "(#{(results[:summary][:pass_rate] * 100).round}%)"

            (annotations + [summary]).join("\n")
          end
        end
      end
    end
  end
end
