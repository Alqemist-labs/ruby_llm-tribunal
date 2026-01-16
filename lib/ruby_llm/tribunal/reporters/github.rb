# frozen_string_literal: true

module RubyLLM
  module Tribunal
    module Reporters
      # GitHub Actions annotations format.
      class GitHub
        class << self
          def format(results)
            annotations = results[:cases]
                          .select { |c| c[:status] == :failed }
                          .map do |c|
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
