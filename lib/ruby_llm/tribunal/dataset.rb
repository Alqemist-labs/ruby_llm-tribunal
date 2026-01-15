# frozen_string_literal: true

module RubyLLM
  module Tribunal
    # Loads evaluation datasets from JSON or YAML files.
    #
    # @example Dataset Format (JSON)
    #   [
    #     {
    #       "input": "What's the return policy?",
    #       "context": "Returns accepted within 30 days.",
    #       "expected": {
    #         "contains": ["30 days"],
    #         "faithful": {"threshold": 0.8}
    #       }
    #     }
    #   ]
    #
    # @example Dataset Format (YAML)
    #   - input: What's the return policy?
    #     context: Returns accepted within 30 days.
    #     expected:
    #       contains:
    #         - 30 days
    #       faithful:
    #         threshold: 0.8
    module Dataset
      class << self
        # Loads a dataset from a file path.
        #
        # @param path [String] Path to the dataset file
        # @return [Array<TestCase>] Array of test cases
        # @raise [Error] If file cannot be loaded or parsed
        def load(path)
          content = File.read(path)
          data = parse(path, content)
          data.map { |item| to_test_case(item) }
        end

        # Loads a dataset and extracts assertions per test case.
        #
        # @param path [String] Path to the dataset file
        # @return [Array<Array(TestCase, Array)>] Array of [test_case, assertions] pairs
        def load_with_assertions(path)
          content = File.read(path)
          data = parse(path, content)

          data.map do |item|
            test_case = to_test_case(item)
            assertions = extract_assertions(item)
            [test_case, assertions]
          end
        end

        private

        def parse(path, content)
          ext = File.extname(path).downcase

          case ext
          when '.json'
            JSON.parse(content)
          when '.yaml', '.yml'
            YAML.safe_load(content, permitted_classes: [Symbol])
          else
            raise Error, "Unsupported file format: #{ext}"
          end
        rescue JSON::ParserError, Psych::SyntaxError => e
          raise Error, "Failed to parse #{path}: #{e.message}"
        end

        def to_test_case(item)
          TestCase.new(item)
        end

        def extract_assertions(item)
          expected = item['expected'] || item[:expected] || {}
          normalize_assertions(expected)
        end

        def normalize_assertions(expected)
          case expected
          when Hash
            expected.map do |type, opts|
              [normalize_type(type), normalize_opts(opts)]
            end
          when Array
            expected.map do |item|
              case item
              when Symbol, String
                [normalize_type(item), {}]
              when Array
                type, opts = item
                [normalize_type(type), normalize_opts(opts)]
              when Hash
                item.map { |t, o| [normalize_type(t), normalize_opts(o)] }
              else
                raise ArgumentError, "Invalid assertion format: #{item.inspect}"
              end
            end.flatten(1)
          else
            []
          end
        end

        def normalize_type(type)
          type.to_s.to_sym
        end

        def normalize_opts(opts)
          return opts.transform_keys(&:to_sym) if opts.is_a?(Hash)

          { value: opts }
        end
      end
    end
  end
end
