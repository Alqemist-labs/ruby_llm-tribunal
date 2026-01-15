#!/usr/bin/env ruby
# frozen_string_literal: true

# ============================================================================
# EXAMPLE 1: RAG System Evaluation
# ============================================================================
#
# This script demonstrates how to evaluate responses from a RAG (Retrieval
# Augmented Generation) system to verify they are faithful to source documents.
#
# Usage: OPENAI_API_KEY=xxx ruby examples/01_rag_evaluation.rb
# ============================================================================

require 'bundler/setup'
require 'ruby_llm'
require 'ruby_llm/tribunal'

# Configure RubyLLM (use your API key)
RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
  # Or for Anthropic:
  # config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
end

# Configure Tribunal
RubyLLM::Tribunal.configure do |config|
  config.default_model = 'gpt-4o-mini' # Model for the "judge"
  config.default_threshold = 0.7
  config.verbose = true # Show evaluation details
end

puts '=' * 70
puts 'EXAMPLE: RAG Evaluation with Tribunal'
puts '=' * 70

# ============================================================================
# Simulate your RAG system
# ============================================================================

# Your knowledge base documents
KNOWLEDGE_BASE = [
  'Our return policy allows returns within 30 days of purchase ' \
  'with a receipt. Items must be in original condition.',

  'We ship to the continental US within 3-5 business days. ' \
  'Shipping is free on orders over $50.',

  'Our customer service is available Monday through Friday, 9am to 6pm. ' \
  'You can reach us at support@example.com.'
].freeze

# Simulate your RAG response (in production, you'd call your actual system)
def simulate_rag_response(query, context)
  chat = RubyLLM.chat(model: 'gpt-4o-mini')
  chat.ask(<<~PROMPT)
    You are an assistant that answers ONLY based on the provided context.
    Do not make up information.

    Context:
    #{context.join("\n")}

    Question: #{query}

    Answer concisely and factually.
  PROMPT
end

# ============================================================================
# Test cases
# ============================================================================

test_cases = [
  {
    query: 'What is the return policy?',
    context: [KNOWLEDGE_BASE[0]],
    expected_keywords: ['30 days', 'receipt']
  },
  {
    query: 'How long does shipping take?',
    context: [KNOWLEDGE_BASE[1]],
    expected_keywords: ['3-5', 'business days']
  },
  {
    query: 'What are the customer service hours?',
    context: [KNOWLEDGE_BASE[2]],
    expected_keywords: %w[9am 6pm Monday Friday]
  }
]

# ============================================================================
# Run evaluations
# ============================================================================

results = []

test_cases.each_with_index do |tc, idx|
  puts "\n#{'-' * 70}"
  puts "Test #{idx + 1}: #{tc[:query]}"
  puts '-' * 70

  # 1. Get RAG response
  puts "\n📝 Calling LLM..."
  response = simulate_rag_response(tc[:query], tc[:context])
  puts "📤 Response: #{response.content}"

  # 2. Create Tribunal test case
  test_case = RubyLLM::Tribunal.test_case(
    input: tc[:query],
    actual_output: response.content,
    context: tc[:context]
  )

  # 3. Deterministic evaluations (fast, free)
  puts "\n🔍 Deterministic evaluations:"
  tc[:expected_keywords].each do |keyword|
    result = RubyLLM::Tribunal::Assertions::Deterministic.evaluate(
      :contains,
      response.content,
      value: keyword
    )
    status = result.first == :pass ? '✅' : '❌'
    puts "   #{status} Contains '#{keyword}': #{result.first}"
  end

  # 4. LLM-as-Judge evaluation (more accurate, costs tokens)
  puts "\n🤖 LLM-as-Judge evaluation:"

  # Check if response is faithful to context
  faithful_result = RubyLLM::Tribunal::Assertions.evaluate(
    :faithful,
    test_case,
    model: 'gpt-4o-mini'
  )

  status, details = faithful_result
  puts "   #{status == :pass ? '✅' : '❌'} Faithfulness: #{details[:verdict]}"
  puts "   Score: #{details[:score]}"
  puts "   Reason: #{details[:reason]}"

  results << {
    query: tc[:query],
    response: response.content,
    faithful: status == :pass
  }
end

# ============================================================================
# Summary
# ============================================================================

puts "\n#{'=' * 70}"
puts 'SUMMARY'
puts '=' * 70

passed = results.count { |r| r[:faithful] }
total = results.length

puts "Faithfulness tests: #{passed}/#{total} (#{(passed.to_f / total * 100).round}%)"

results.each_with_index do |r, idx|
  status = r[:faithful] ? '✅' : '❌'
  puts "  #{status} Test #{idx + 1}: #{r[:query][0, 40]}..."
end
