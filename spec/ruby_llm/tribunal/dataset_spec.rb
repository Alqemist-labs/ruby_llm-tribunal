# frozen_string_literal: true

RSpec.describe RubyLLM::Tribunal::Dataset do
  let(:json_path) { 'spec/fixtures/test_dataset.json' }
  let(:yaml_path) { 'spec/fixtures/test_dataset.yaml' }

  before do
    FileUtils.mkdir_p('spec/fixtures')

    File.write(json_path, <<~JSON)
      [
        {
          "input": "What is the return policy?",
          "context": "Returns accepted within 30 days.",
          "expected": {
            "contains": ["30 days"],
            "faithful": {"threshold": 0.8}
          }
        },
        {
          "input": "Do you ship internationally?",
          "context": "We ship to US and Canada only.",
          "expected": {
            "contains_any": ["US", "Canada"]
          }
        }
      ]
    JSON

    File.write(yaml_path, <<~YAML)
      - input: What is the return policy?
        context: Returns accepted within 30 days.
        expected:
          contains:
            - 30 days
          faithful:
            threshold: 0.8
    YAML
  end

  after do
    FileUtils.rm_f(json_path)
    FileUtils.rm_f(yaml_path)
  end

  describe '.load' do
    it 'loads test cases from JSON file' do
      test_cases = described_class.load(json_path)

      expect(test_cases.length).to eq(2)
      expect(test_cases[0].input).to eq('What is the return policy?')
      expect(test_cases[0].context).to eq(['Returns accepted within 30 days.'])
    end

    it 'loads test cases from YAML file' do
      test_cases = described_class.load(yaml_path)

      expect(test_cases.length).to eq(1)
      expect(test_cases[0].input).to eq('What is the return policy?')
    end
  end

  describe '.load_with_assertions' do
    it 'loads test cases with their assertions from JSON' do
      cases = described_class.load_with_assertions(json_path)

      expect(cases.length).to eq(2)

      test_case, assertions = cases[0]
      expect(test_case.input).to eq('What is the return policy?')
      expect(assertions).to include([:contains, { value: ['30 days'] }])
      expect(assertions).to include([:faithful, { threshold: 0.8 }])
    end

    it 'loads test cases with their assertions from YAML' do
      cases = described_class.load_with_assertions(yaml_path)

      expect(cases.length).to eq(1)

      test_case, assertions = cases[0]
      expect(test_case.input).to eq('What is the return policy?')
      expect(assertions).to include([:contains, { value: ['30 days'] }])
    end
  end
end
