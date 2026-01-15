# frozen_string_literal: true

RSpec.describe RubyLLM::Tribunal::Reporter do
  let(:results) do
    {
      summary: {
        total: 10,
        passed: 8,
        failed: 2,
        pass_rate: 0.8,
        duration_ms: 1500
      },
      metrics: {
        contains: { passed: 5, total: 5 },
        faithful: { passed: 3, total: 5 }
      },
      cases: [
        { input: 'Test 1', status: :passed, failures: [], results: {}, duration_ms: 100 },
        { input: 'Test 2', status: :failed, failures: [[:faithful, 'Not faithful']], results: {}, duration_ms: 200 }
      ]
    }
  end

  describe '.format' do
    it 'formats with console reporter by default' do
      output = described_class.format(results)

      expect(output).to include('Tribunal LLM Evaluation')
      expect(output).to include('Total:')
      expect(output).to include('10 test cases')
      expect(output).to include('80%')
    end

    it 'formats with text reporter' do
      output = described_class.format(results, :text)

      expect(output).to include('Tribunal LLM Evaluation')
      expect(output).to include('===')
      expect(output).not_to include('═')
    end

    it 'formats with json reporter' do
      output = described_class.format(results, :json)
      parsed = JSON.parse(output)

      expect(parsed['summary']['total']).to eq(10)
      expect(parsed['summary']['passed']).to eq(8)
    end

    it 'formats with html reporter' do
      output = described_class.format(results, :html)

      expect(output).to include('<!DOCTYPE html>')
      expect(output).to include('Tribunal Evaluation Report')
      expect(output).to include('10')
    end

    it 'formats with github reporter' do
      output = described_class.format(results, :github)

      expect(output).to include('::notice::')
      expect(output).to include('8/10 passed')
    end

    it 'formats with junit reporter' do
      output = described_class.format(results, :junit)

      expect(output).to include('<?xml version="1.0"')
      expect(output).to include('<testsuites')
      expect(output).to include('tests="10"')
    end

    it 'raises for unknown format' do
      expect { described_class.format(results, :unknown) }.to raise_error(ArgumentError)
    end
  end

  describe '.available_formats' do
    it 'returns available formats' do
      formats = described_class.available_formats

      expect(formats).to include(:console)
      expect(formats).to include(:text)
      expect(formats).to include(:json)
      expect(formats).to include(:html)
      expect(formats).to include(:github)
      expect(formats).to include(:junit)
    end
  end
end
