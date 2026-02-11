# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Pollinations::Chat do
  include_context 'with configured RubyLLM'

  let(:test_obj) do
    Object.new.tap do |obj|
      obj.extend(RubyLLM::Providers::Pollinations::Media)
      obj.extend(RubyLLM::Providers::Pollinations::Tools)
      obj.extend(described_class)
    end
  end

  describe '.completion_url' do
    it 'returns OpenAI-compatible endpoint' do
      expect(test_obj.completion_url).to eq('v1/chat/completions')
    end
  end

  describe '.render_payload' do
    let(:model) { instance_double(RubyLLM::Model::Info, id: 'openai') }
    let(:messages) do
      [
        RubyLLM::Message.new(role: :user, content: 'Hello')
      ]
    end

    it 'renders basic payload with model and messages' do
      payload = described_class.render_payload(
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: false
      )

      expect(payload[:model]).to eq('openai')
      expect(payload[:messages]).to be_an(Array)
      expect(payload[:stream]).to eq(false)
    end

    it 'includes temperature when provided' do
      payload = described_class.render_payload(
        messages,
        tools: {},
        temperature: 0.7,
        model: model,
        stream: false
      )

      expect(payload[:temperature]).to eq(0.7)
    end

    it 'omits temperature when nil' do
      payload = described_class.render_payload(
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: false
      )

      expect(payload).not_to have_key(:temperature)
    end

    it 'includes stream_options when streaming' do
      payload = described_class.render_payload(
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: true
      )

      expect(payload[:stream]).to eq(true)
      expect(payload[:stream_options]).to eq({ include_usage: true })
    end

    it 'includes json_schema response_format when schema provided' do
      schema = { type: 'object', properties: { name: { type: 'string' } } }

      payload = described_class.render_payload(
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: schema
      )

      expect(payload[:response_format][:type]).to eq('json_schema')
      expect(payload[:response_format][:json_schema][:name]).to eq('response')
      expect(payload[:response_format][:json_schema][:schema]).to eq(schema)
      expect(payload[:response_format][:json_schema][:strict]).to eq(true)
    end

    it 'respects strict: false in schema' do
      schema = { type: 'object', strict: false }

      payload = described_class.render_payload(
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        schema: schema
      )

      expect(payload[:response_format][:json_schema][:strict]).to eq(false)
    end

    it 'includes reasoning_effort when thinking provided as string' do
      payload = described_class.render_payload(
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        thinking: 'high'
      )

      expect(payload[:reasoning_effort]).to eq('high')
    end

    it 'extracts effort from thinking object with .effort method' do
      thinking_obj = double('ThinkingConfig', effort: 'medium')

      payload = described_class.render_payload(
        messages,
        tools: {},
        temperature: nil,
        model: model,
        stream: false,
        thinking: thinking_obj
      )

      expect(payload[:reasoning_effort]).to eq('medium')
    end
  end

  describe '.parse_completion_response' do
    it 'parses standard completion response' do
      response_body = {
        'model' => 'openai',
        'choices' => [
          {
            'message' => {
              'role' => 'assistant',
              'content' => 'Hello there!'
            }
          }
        ],
        'usage' => {
          'prompt_tokens' => 10,
          'completion_tokens' => 5
        }
      }

      response = instance_double(Faraday::Response, body: response_body)

      message = described_class.parse_completion_response(response)

      expect(message.role).to eq(:assistant)
      expect(message.content).to eq('Hello there!')
      expect(message.input_tokens).to eq(10)
      expect(message.output_tokens).to eq(5)
      expect(message.model_id).to eq('openai')
    end

    it 'captures cached token information' do
      response_body = {
        'model' => 'openai',
        'choices' => [
          {
            'message' => {
              'role' => 'assistant',
              'content' => 'Cached response'
            }
          }
        ],
        'usage' => {
          'prompt_tokens' => 100,
          'completion_tokens' => 20,
          'prompt_tokens_details' => { 'cached_tokens' => 80 }
        }
      }

      response = instance_double(Faraday::Response, body: response_body)

      message = described_class.parse_completion_response(response)

      expect(message.cached_tokens).to eq(80)
      expect(message.cache_creation_tokens).to eq(0)
    end

    it 'captures thinking/reasoning tokens' do
      response_body = {
        'model' => 'openai',
        'choices' => [
          {
            'message' => {
              'role' => 'assistant',
              'content' => 'Thought through response'
            }
          }
        ],
        'usage' => {
          'prompt_tokens' => 50,
          'completion_tokens' => 30,
          'completion_tokens_details' => { 'reasoning_tokens' => 15 }
        }
      }

      response = instance_double(Faraday::Response, body: response_body)

      message = described_class.parse_completion_response(response)

      expect(message.thinking_tokens).to eq(15)
    end

    it 'extracts reasoning_content as thinking' do
      response_body = {
        'model' => 'openai',
        'choices' => [
          {
            'message' => {
              'role' => 'assistant',
              'content' => 'Final answer',
              'reasoning_content' => 'Let me think about this...'
            }
          }
        ],
        'usage' => {}
      }

      response = instance_double(Faraday::Response, body: response_body)

      message = described_class.parse_completion_response(response)

      expect(message.content).to eq('Final answer')
      expect(message.thinking).not_to be_nil
    end

    it 'raises error when response contains error' do
      response_body = {
        'error' => {
          'message' => 'Invalid API key'
        }
      }

      response = instance_double(Faraday::Response, body: response_body)

      expect do
        described_class.parse_completion_response(response)
      end.to raise_error(RubyLLM::Error)
    end

    it 'returns nil for empty response body' do
      response = instance_double(Faraday::Response, body: nil)
      expect(described_class.parse_completion_response(response)).to be_nil

      response2 = instance_double(Faraday::Response, body: {})
      expect(described_class.parse_completion_response(response2)).to be_nil
    end
  end

  describe '.extract_content_and_thinking' do
    it 'extracts content from <think> tags' do
      text = '<think>Internal reasoning</think>Final answer'

      content, thinking = described_class.extract_content_and_thinking(text)

      expect(content).to eq('Final answer')
      expect(thinking).to eq('Internal reasoning')
    end

    it 'handles multiple think tags' do
      text = '<think>First thought</think>Part 1<think>Second thought</think>Part 2'

      content, thinking = described_class.extract_content_and_thinking(text)

      expect(content).to eq('Part 1Part 2')
      expect(thinking).to eq('First thoughtSecond thought')
    end

    it 'returns original text when no think tags' do
      text = 'Just a regular response'

      content, thinking = described_class.extract_content_and_thinking(text)

      expect(content).to eq('Just a regular response')
      expect(thinking).to be_nil
    end

    it 'handles array content with text blocks' do
      content_array = [
        { 'type' => 'text', 'text' => 'Hello ' },
        { 'type' => 'text', 'text' => 'World' }
      ]

      content, thinking = described_class.extract_content_and_thinking(content_array)

      expect(content).to eq('Hello World')
      expect(thinking).to be_nil
    end

    it 'extracts thinking from thinking blocks' do
      content_array = [
        { 'type' => 'thinking', 'thinking' => 'Internal thought' },
        { 'type' => 'text', 'text' => 'Final answer' }
      ]

      content, thinking = described_class.extract_content_and_thinking(content_array)

      expect(content).to eq('Final answer')
      expect(thinking).to eq('Internal thought')
    end
  end

  describe '.format_messages' do
    it 'formats simple user message' do
      messages = [
        RubyLLM::Message.new(role: :user, content: 'Hello')
      ]

      formatted = test_obj.send(:format_messages, messages)

      expect(formatted.length).to eq(1)
      expect(formatted[0][:role]).to eq('user')
    end

    it 'includes tool_call_id for tool messages' do
      messages = [
        RubyLLM::Message.new(role: :tool, content: 'Result', tool_call_id: 'call_123')
      ]

      formatted = test_obj.send(:format_messages, messages)

      expect(formatted[0][:tool_call_id]).to eq('call_123')
    end

    it 'compacts nil values' do
      messages = [
        RubyLLM::Message.new(role: :user, content: 'Hello')
      ]

      formatted = test_obj.send(:format_messages, messages)

      expect(formatted[0]).not_to have_key(:tool_calls)
      expect(formatted[0]).not_to have_key(:tool_call_id)
    end
  end
end
