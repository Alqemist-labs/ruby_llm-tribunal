# frozen_string_literal: true

module RubyLLM
  module Tribunal
    module Reporters
      # Plain ASCII text output (no unicode).
      class Text
        class << self
          def format(results)
            [
              header,
              summary_section(results[:summary]),
              metrics_section(results[:metrics]),
              failures_section(results[:cases]),
              footer(results[:summary])
            ].join("\n")
          end

          private

          def header
            <<~HEADER

              Tribunal LLM Evaluation
              ===================================================================
            HEADER
          end

          def summary_section(summary)
            <<~SUMMARY
              Summary
              -------------------------------------------------------------------
                Total:     #{summary[:total]} test cases
                Passed:    #{summary[:passed]} (#{(summary[:pass_rate] * 100).round}%)
                Failed:    #{summary[:failed]}
                Duration:  #{format_duration(summary[:duration_ms])}
            SUMMARY
          end

          def metrics_section(metrics)
            return '' if metrics.nil? || metrics.empty?

            rows = metrics.map do |name, data|
              rate = data[:total].positive? ? data[:passed].to_f / data[:total] : 0
              bar = progress_bar(rate, 20)
              "  #{pad(name, 14)} #{data[:passed]}/#{data[:total]} passed   #{(rate * 100).round}%   #{bar}"
            end.join("\n")

            <<~METRICS
              Results by Metric
              -------------------------------------------------------------------
              #{rows}
            METRICS
          end

          def failures_section(cases)
            failures = cases.select { |c| c[:status] == :failed }
            return '' if failures.empty?

            rows = failures.each_with_index.map do |c, idx|
              format_failure_row(c, idx + 1)
            end.join("\n")

            <<~FAILURES
              Failed Cases
              -------------------------------------------------------------------
              #{rows}
            FAILURES
          end

          def format_failure_row(test_case, idx)
            input = test_case[:input].to_s[0, 50]
            reasons = test_case[:failures].map do |type, reason|
              "     |- #{type}: #{reason}"
            end.join("\n")

            <<~ROW
                #{idx}. "#{input}"
              #{reasons}
            ROW
          end

          def footer(summary)
            passed = summary[:threshold_passed] != false && summary[:failed].zero?
            status = passed ? 'PASSED' : 'FAILED'

            threshold_info = if summary[:strict]
                               ' (strict mode)'
                             elsif summary[:threshold]
                               " (threshold: #{(summary[:threshold] * 100).round}%)"
                             else
                               ''
                             end

            <<~FOOTER
              -------------------------------------------------------------------
              #{status}#{threshold_info}
            FOOTER
          end

          def progress_bar(rate, width)
            filled = (rate * width).round
            empty = width - filled
            "#{'#' * filled}#{'-' * empty}"
          end

          def pad(term, width)
            term.to_s.ljust(width)
          end

          def format_duration(duration_ms)
            return "#{duration_ms}ms" if duration_ms < 1000

            "#{(duration_ms / 1000.0).round(1)}s"
          end
        end
      end
    end
  end
end
