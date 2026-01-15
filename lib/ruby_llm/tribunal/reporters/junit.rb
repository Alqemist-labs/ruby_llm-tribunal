# frozen_string_literal: true

module RubyLLM
  module Tribunal
    module Reporters
      # JUnit XML format for CI tools.
      class JUnit
        class << self
          def format(results)
            test_cases = results[:cases].map { |c| format_testcase(c) }.join("\n")

            <<~XML
              <?xml version="1.0" encoding="UTF-8"?>
              <testsuites name="Tribunal" tests="#{results[:summary][:total]}" failures="#{results[:summary][:failed]}" time="#{results[:summary][:duration_ms] / 1000.0}">
                <testsuite name="eval" tests="#{results[:summary][:total]}" failures="#{results[:summary][:failed]}">
              #{test_cases}
                </testsuite>
              </testsuites>
            XML
          end

          private

          def format_testcase(test_case)
            name = escape_xml(test_case[:input].to_s)
            time = (test_case[:duration_ms] || 0) / 1000.0

            return %(    <testcase name="#{name}" time="#{time}"/>) if test_case[:status] == :passed

            failure_msg = test_case[:failures]
                          .map { |type, reason| "#{type}: #{reason}" }
                          .join("\n")
                          .then { |msg| escape_xml(msg) }

            build_failure_xml(name, time, failure_msg)
          end

          def build_failure_xml(name, time, failure_msg)
            <<~XML.chomp
              <testcase name="#{name}" time="#{time}">
                <failure message="Assertion failed">#{failure_msg}</failure>
              </testcase>
            XML
          end

          def escape_xml(str)
            str.to_s
               .gsub('&', '&amp;')
               .gsub('<', '&lt;')
               .gsub('>', '&gt;')
               .gsub('"', '&quot;')
               .gsub("'", '&apos;')
          end
        end
      end
    end
  end
end
