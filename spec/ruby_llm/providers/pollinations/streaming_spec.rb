# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Pollinations::Streaming do
  include_context 'with configured RubyLLM'

  describe '.build_chunk' do
    it 'builds chunk from SSE delta data' do
      data = {
        'model' => 'openai',
        'choices' => [
          {
            'delta' => {
              'content' => 'Hello'
            }
          }
        ],
        'usage' => {}
      }

      chunk = described_class.build_chunk(data)

      expect(chunk).to be_a(RubyLLM::Chunk)
      expect(chunk.role).to eq(:assistant)
      expect(chunk.content).to eq('Hello')
      expect(chunk.model_id).to eq('openai')
    end

    it 'handles usage data in final chunk' do
      data = {
        'model' => 'openai',
        'choices' => [{ 'delta' => {} }],
        'usage' => {
          'prompt_tokens' => 100,
          'completion_tokens' => 50,
          'prompt_tokens_details' => { 'cached_tokens' => 30 },
          'completion_tokens_details' => { 'reasoning_tokens' => 10 }
        }
      }

      chunk = described_class.build_chunk(data)

      expect(chunk.input_tokens).to eq(100)
      expect(chunk.output_tokens).to eq(50)
      expect(chunk.cached_tokens).to eq(30)
      expect(chunk.thinking_tokens).to eq(10)
    end

    it 'extracts reasoning_content as thinking' do
      data = {
        'model' => 'openai',
        'choices' => [
          {
            'delta' => {
              'reasoning_content' => 'Thinking step...'
            }
          }
        ],
        'usage' => {}
      }

      chunk = described_class.build_chunk(data)

      expect(chunk.thinking).not_to be_nil
    end

    it 'parses tool_calls without parsing arguments' do
      data = {
        'model' => 'openai',
        'choices' => [
          {
            'delta' => {
              'tool_calls' => [
                {
                  'id' => 'call_123',
                  'function' => {
                    'name' => 'weather',
                    'arguments' => '{"city": "Berlin"}'
                  }
                }
              ]
            }
          }
        ],
        'usage' => {}
      }

      chunk = described_class.build_chunk(data)

      expect(chunk.tool_calls).not_to be_nil
      expect(chunk.tool_calls['call_123'].name).to eq('weather')
      expect(chunk.tool_calls['call_123'].arguments).to eq('{"city": "Berlin"}')
    end

    it 'handles content from message fallback' do
      data = {
        'model' => 'openai',
        'choices' => [
          {
            'message' => { 'content' => 'Fallback content' }
          }
        ],
        'usage' => {}
      }

      chunk = described_class.build_chunk(data)

      expect(chunk.content).to eq('Fallback content')
    end

    it 'extracts thinking from think tags in content' do
      data = {
        'model' => 'openai',
        'choices' => [
          {
            'delta' => {
              'content' => '<think>Internal thought</think>Answer'
            }
          }
        ],
        'usage' => {}
      }

      chunk = described_class.build_chunk(data)

      expect(chunk.content).to eq('Answer')
      expect(chunk.thinking).not_to be_nil
    end
  end

  describe '.parse_streaming_error' do
    it 'returns 429 for rate limit errors' do
      data = JSON.generate({
                             'error' => {
                               'code' => 'rate_limit_exceeded',
                               'message' => 'Too many requests'
                             }
                           })

      code, message = described_class.parse_streaming_error(data)

      expect(code).to eq(429)
      expect(message).to eq('Too many requests')
    end

    it 'returns 429 for RATE_LIMIT code' do
      data = JSON.generate({
                             'error' => {
                               'code' => 'RATE_LIMIT',
                               'message' => 'Rate limited'
                             }
                           })

      code, = described_class.parse_streaming_error(data)

      expect(code).to eq(429)
    end

    it 'returns 429 for insufficient_quota' do
      data = JSON.generate({
                             'error' => {
                               'code' => 'insufficient_quota',
                               'message' => 'Quota exceeded'
                             }
                           })

      code, = described_class.parse_streaming_error(data)

      expect(code).to eq(429)
    end

    it 'returns 500 for server errors' do
      data = JSON.generate({
                             'error' => {
                               'code' => 'server_error',
                               'message' => 'Internal error'
                             }
                           })

      code, = described_class.parse_streaming_error(data)

      expect(code).to eq(500)
    end

    it 'returns 500 for INTERNAL_ERROR code' do
      data = JSON.generate({
                             'error' => {
                               'code' => 'INTERNAL_ERROR',
                               'message' => 'Something went wrong'
                             }
                           })

      code, = described_class.parse_streaming_error(data)

      expect(code).to eq(500)
    end

    it 'returns 401 for unauthorized' do
      data = JSON.generate({
                             'error' => {
                               'code' => 'UNAUTHORIZED',
                               'message' => 'Invalid API key'
                             }
                           })

      code, = described_class.parse_streaming_error(data)

      expect(code).to eq(401)
    end

    it 'returns 402 for payment required' do
      data = JSON.generate({
                             'error' => {
                               'code' => 'PAYMENT_REQUIRED',
                               'message' => 'Payment needed'
                             }
                           })

      code, = described_class.parse_streaming_error(data)

      expect(code).to eq(402)
    end

    it 'returns 400 for unknown error codes' do
      data = JSON.generate({
                             'error' => {
                               'code' => 'unknown_error',
                               'message' => 'Unknown issue'
                             }
                           })

      code, message = described_class.parse_streaming_error(data)

      expect(code).to eq(400)
      expect(message).to eq('Unknown issue')
    end

    it 'uses type field when code is missing' do
      data = JSON.generate({
                             'error' => {
                               'type' => 'rate_limit_exceeded',
                               'message' => 'Slow down'
                             }
                           })

      code, = described_class.parse_streaming_error(data)

      expect(code).to eq(429)
    end

    it 'returns nil when no error in data' do
      data = JSON.generate({ 'result' => 'ok' })

      result = described_class.parse_streaming_error(data)

      expect(result).to be_nil
    end
  end
end
