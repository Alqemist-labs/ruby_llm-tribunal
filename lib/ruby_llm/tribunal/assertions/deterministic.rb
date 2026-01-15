# frozen_string_literal: true

module RubyLLM
  module Tribunal
    module Assertions
      # Deterministic assertions that don't require LLM calls.
      #
      # Fast, free, and should run first before expensive LLM-based checks.
      module Deterministic
        class << self
          # Evaluates a deterministic assertion.
          #
          # @param type [Symbol] The assertion type
          # @param output [String] The output to evaluate
          # @param opts [Hash] Options for the assertion
          # @return [Array] [:pass, details] or [:fail, details]
          #
          # @example
          #   evaluate(:contains, "Hello world", value: "world")
          #   #=> [:pass, { matched: ["world"] }]
          def evaluate(type, output, opts = {})
            send(:"evaluate_#{type}", output, opts)
          end

          private

          def evaluate_contains(output, opts)
            values = Array(opts[:value] || opts[:values])
            results = values.map { |v| [v, output.include?(v)] }

            if results.all? { |_, matched| matched }
              [:pass, { matched: values }]
            else
              missing = results.reject { |_, m| m }.map(&:first)
              [:fail, { missing:, reason: "Output missing: #{missing.inspect}" }]
            end
          end

          def evaluate_not_contains(output, opts)
            values = Array(opts[:value] || opts[:values])
            found = values.select { |v| output.include?(v) }

            if found.empty?
              [:pass, { checked: values }]
            else
              [:fail, { found:, reason: "Output contains forbidden: #{found.inspect}" }]
            end
          end

          def evaluate_contains_any(output, opts)
            values = Array(opts[:value] || opts[:values])
            found = values.find { |v| output.include?(v) }

            if found
              [:pass, { matched: found }]
            else
              [:fail, { expected_any: values, reason: "Output contains none of: #{values.inspect}" }]
            end
          end

          def evaluate_contains_all(output, opts)
            values = Array(opts[:value] || opts[:values])
            results = values.map { |v| [v, output.include?(v)] }

            if results.all? { |_, matched| matched }
              [:pass, { matched: values }]
            else
              missing = results.reject { |_, m| m }.map(&:first)
              [:fail, { missing:, reason: "Output missing: #{missing.inspect}" }]
            end
          end

          def evaluate_regex(output, opts)
            pattern = opts[:value] || opts[:pattern]
            regex = pattern.is_a?(Regexp) ? pattern : Regexp.new(pattern)

            match = output.match(regex)
            if match
              [:pass, { matched: match[0], pattern: regex.source }]
            else
              [:fail, { pattern: regex.source, reason: "Pattern not found: #{regex.source}" }]
            end
          end

          def evaluate_is_json(output, _opts)
            parsed = JSON.parse(output)
            [:pass, { parsed: }]
          rescue JSON::ParserError
            [:fail, { reason: 'Invalid JSON' }]
          end

          def evaluate_max_tokens(output, opts)
            max = opts[:value] || opts[:max] || 500

            # Approximate: 1 token ~= 0.75 words ~= 4 chars
            # Using word count as a reasonable approximation
            word_count = output.split(/\s+/).length
            approx_tokens = (word_count / 0.75).ceil

            if approx_tokens <= max
              [:pass, { approx_tokens:, max: }]
            else
              [:fail, {
                approx_tokens:,
                max:,
                reason: "Output ~#{approx_tokens} tokens exceeds max #{max}"
              }]
            end
          end

          def evaluate_latency_ms(_output, opts)
            max = opts[:value] || opts[:max] || 5000
            actual = opts[:actual] || opts[:latency]

            if actual.nil?
              [:fail, { reason: 'No latency value provided in opts[:actual]' }]
            elsif actual <= max
              [:pass, { latency_ms: actual, max: }]
            else
              [:fail, { latency_ms: actual, max:, reason: "Latency #{actual}ms exceeds max #{max}ms" }]
            end
          end

          def evaluate_starts_with(output, opts)
            prefix = opts[:value]

            if output.start_with?(prefix)
              [:pass, { prefix: }]
            else
              [:fail, { expected: prefix, reason: "Output does not start with: #{prefix}" }]
            end
          end

          def evaluate_ends_with(output, opts)
            suffix = opts[:value]

            if output.end_with?(suffix)
              [:pass, { suffix: }]
            else
              [:fail, { expected: suffix, reason: "Output does not end with: #{suffix}" }]
            end
          end

          def evaluate_equals(output, opts)
            expected = opts[:value]

            if output == expected
              [:pass, {}]
            else
              [:fail, { expected:, actual: output, reason: 'Output does not match expected' }]
            end
          end

          def evaluate_min_length(output, opts)
            min = opts[:value] || opts[:min]
            length = output.length

            if length >= min
              [:pass, { length:, min: }]
            else
              [:fail, { length:, min:, reason: "Output length #{length} below minimum #{min}" }]
            end
          end

          def evaluate_max_length(output, opts)
            max = opts[:value] || opts[:max]
            length = output.length

            if length <= max
              [:pass, { length:, max: }]
            else
              [:fail, { length:, max:, reason: "Output length #{length} exceeds maximum #{max}" }]
            end
          end

          def evaluate_word_count(output, opts)
            min = opts[:min] || 0
            max = opts[:max]

            words = output.split(/\s+/).reject(&:empty?)
            count = words.length

            if count < min
              [:fail, { word_count: count, min:, reason: "Word count #{count} below minimum #{min}" }]
            elsif max && count > max
              [:fail, { word_count: count, max:, reason: "Word count #{count} exceeds maximum #{max}" }]
            else
              [:pass, { word_count: count }]
            end
          end

          def evaluate_is_url(output, _opts)
            url = output.strip

            if url.match?(%r{^https?://[^\s]+$})
              [:pass, { url: }]
            else
              [:fail, { reason: 'Output is not a valid URL' }]
            end
          end

          def evaluate_is_email(output, _opts)
            email = output.strip

            if email.match?(/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/)
              [:pass, { email: }]
            else
              [:fail, { reason: 'Output is not a valid email' }]
            end
          end

          def evaluate_levenshtein(output, opts)
            target = opts[:value]
            max_distance = opts[:max_distance] || 3

            distance = levenshtein_distance(output, target)

            if distance <= max_distance
              [:pass, { distance:, max_distance: }]
            else
              [:fail, {
                distance:,
                max_distance:,
                reason: "Edit distance #{distance} exceeds max #{max_distance}"
              }]
            end
          end

          # Levenshtein distance algorithm
          def levenshtein_distance(s1, s2)
            s1_chars = s1.chars
            s2_chars = s2.chars

            return s2_chars.length if s1_chars.empty?
            return s1_chars.length if s2_chars.empty?

            row = (0..s2_chars.length).to_a

            s1_chars.each_with_index do |c1, i|
              prev_row = row
              row = [i + 1]

              s2_chars.each_with_index do |c2, j|
                cost = c1 == c2 ? 0 : 1
                row << [
                  row[j] + 1,           # deletion
                  prev_row[j + 1] + 1,  # insertion
                  prev_row[j] + cost    # substitution
                ].min
              end
            end

            row.last
          end
        end
      end
    end
  end
end
