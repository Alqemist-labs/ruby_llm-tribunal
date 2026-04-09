#!/usr/bin/env ruby
# frozen_string_literal: true

# ============================================================================
# EXAMPLE 3: RSpec Integration Patterns
# ============================================================================
#
# This script demonstrates how to use Tribunal's EvalHelpers module
# within RSpec to evaluate LLM outputs as part of your test suite.
#
# Usage:
#   # Deterministic assertions only (no API key needed):
#   rspec examples/03_rspec_integration.rb
#
#   # Include LLM-as-judge assertions:
#   OPENAI_API_KEY=xxx rspec examples/03_rspec_integration.rb
# ============================================================================

require 'bundler/setup'
require 'ruby_llm'
require 'ruby_llm/tribunal'
require 'rspec/autorun'

# Configure Tribunal
RubyLLM::Tribunal.configure do |config|
  config.default_model = 'gpt-4o-mini'
  config.default_threshold = 0.7
  config.verbose = true
end

# ============================================================================
# Simulate your application's LLM-powered features
# ============================================================================

module MyApp
  # A simple FAQ bot that answers based on provided knowledge
  class FAQBot
    KNOWLEDGE = {
      'return_policy' => 'Our return policy allows returns within 30 days of purchase ' \
                         'with a receipt. Items must be in original condition.',
      'shipping' => 'We ship to the continental US within 3-5 business days. ' \
                    'Shipping is free on orders over $50.',
      'support' => 'Our customer service is available Monday through Friday, 9am to 6pm. ' \
                   'You can reach us at support@example.com.'
    }.freeze

    def answer(topic)
      KNOWLEDGE.fetch(topic, 'Sorry, I do not have information on that topic.')
    end
  end

  # A formatter that produces JSON responses
  class JSONFormatter
    def format(data)
      JSON.generate(data)
    end
  end
end

# ============================================================================
# RSpec integration using EvalHelpers
# ============================================================================

RSpec.describe 'Tribunal RSpec Integration' do
  include RubyLLM::Tribunal::EvalHelpers

  # Disable VCR and WebMock for this example (live API calls)
  # These are loaded automatically via spec_helper from .rspec
  before(:all) do
    VCR.turn_off! if defined?(VCR)
    WebMock.allow_net_connect! if defined?(WebMock)
  end

  after(:all) do
    VCR.turn_on! if defined?(VCR)
    WebMock.disable_net_connect! if defined?(WebMock)
  end

  # --------------------------------------------------------------------------
  # Pattern 1: Deterministic assertions for fast, free checks
  # --------------------------------------------------------------------------
  describe 'Deterministic assertions' do
    let(:faq_bot) { MyApp::FAQBot.new }

    context 'when checking FAQ responses contain expected information' do
      it 'return policy mentions 30 days and receipt' do
        response = faq_bot.answer('return_policy')

        assert_contains response, '30 days'
        assert_contains response, 'receipt'
      end

      it 'shipping info mentions delivery timeframe' do
        response = faq_bot.answer('shipping')

        assert_contains response, '3-5 business days'
        assert_contains response, '$50'
      end

      it 'support info contains all required details' do
        response = faq_bot.answer('support')

        assert_contains_all response, %w[Monday Friday 9am 6pm]
        assert_contains response, 'support@example.com'
      end
    end

    context 'when validating response format' do
      it 'JSON formatter produces valid JSON' do
        formatter = MyApp::JSONFormatter.new
        output = formatter.format({ status: 'ok', items: [1, 2, 3] })

        assert_json output
        assert_contains output, 'status'
      end
    end

    context 'when checking response boundaries' do
      it 'FAQ responses are reasonably sized' do
        response = faq_bot.answer('return_policy')

        assert_min_length response, 20
        assert_max_length response, 500
        assert_word_count response, { min: 5, max: 50 }
      end
    end

    context 'when using negative assertions' do
      it 'FAQ responses do not contain competitor mentions' do
        response = faq_bot.answer('shipping')

        refute_contains response, 'Amazon'
        refute_contains response, 'competitor'
      end
    end

    context 'when checking response patterns' do
      it 'support email matches expected format' do
        response = faq_bot.answer('support')

        assert_regex response, /\S+@\S+\.\S+/
      end

      it 'response starts with expected prefix' do
        response = faq_bot.answer('return_policy')

        assert_starts_with response, 'Our return'
      end
    end

    context 'when topic is unknown' do
      it 'returns a polite fallback' do
        response = faq_bot.answer('unknown_topic')

        assert_contains response, 'Sorry'
        assert_starts_with response, 'Sorry'
      end
    end
  end

  # --------------------------------------------------------------------------
  # Pattern 2: LLM-as-judge assertions for semantic evaluation
  # --------------------------------------------------------------------------
  describe 'LLM-as-judge assertions', if: ENV.fetch('OPENAI_API_KEY', nil) do
    before(:all) do
      RubyLLM.configure do |config|
        config.openai_api_key = ENV.fetch('OPENAI_API_KEY')
      end
    end

    context 'when evaluating faithfulness to source documents' do
      it 'response is faithful to the knowledge base' do
        context = ['Returns are accepted within 30 days of purchase with a valid receipt.']
        response = 'You can return items within 30 days if you have your receipt.'

        assert_faithful response, context: context, query: 'What is the return policy?'
      end
    end

    context 'when evaluating relevance' do
      it 'response is relevant to the question asked' do
        assert_relevant(
          'We ship within 3-5 business days to the continental US.',
          query: 'How long does shipping take?'
        )
      end
    end

    context 'when checking for hallucinations' do
      it 'response does not hallucinate beyond the context' do
        context = ['The store is open Monday to Friday, 9am to 6pm.']
        response = 'Our store hours are Monday through Friday, 9am to 6pm.'

        refute_hallucination response, context: context, query: 'What are the store hours?'
      end
    end

    context 'when evaluating safety' do
      it 'response is not toxic' do
        refute_toxicity 'Hello! How can I help you today?'
      end

      it 'response contains no PII' do
        refute_pii 'Please contact our support team for assistance.'
      end
    end

    context 'when evaluating correctness against expected output' do
      it 'response matches expected answer' do
        assert_correctness(
          'The capital of France is Paris.',
          query: 'What is the capital of France?',
          expected: 'Paris'
        )
      end
    end
  end
end
