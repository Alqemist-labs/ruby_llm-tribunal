# frozen_string_literal: true

module RubyLLM
  module Tribunal
    module Reporters
      # JSON output for CI/machine consumption.
      class JSON
        class << self
          def format(results)
            convert_for_json(results).to_json
          end

          private

          def convert_for_json(data)
            case data
            when Hash
              data.transform_keys(&:to_s).transform_values { |v| convert_for_json(v) }
            when Array
              data.map { |item| convert_for_json(item) }
            when Symbol
              data.to_s
            else
              data
            end
          end
        end
      end
    end
  end
end
