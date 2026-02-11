# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Pollinations::Tools do
  describe '.tool_for' do
    it 'formats tool with function definition' do
      tool = instance_double(
        RubyLLM::Tool,
        name: 'weather',
        description: 'Get weather info',
        parameters: [],
        params_schema: nil,
        provider_params: {}
      )

      result = described_class.tool_for(tool)

      expect(result[:type]).to eq('function')
      expect(result[:function][:name]).to eq('weather')
      expect(result[:function][:description]).to eq('Get weather info')
    end

    it 'uses params_schema when available' do
      custom_schema = {
        'type' => 'object',
        'properties' => { 'city' => { 'type' => 'string' } },
        'required' => ['city']
      }

      tool = instance_double(
        RubyLLM::Tool,
        name: 'weather',
        description: 'Get weather',
        params_schema: custom_schema,
        parameters: [],
        provider_params: {}
      )

      result = described_class.tool_for(tool)

      expect(result[:function][:parameters]).to eq(custom_schema)
    end

    it 'merges provider_params when present' do
      tool = instance_double(
        RubyLLM::Tool,
        name: 'weather',
        description: 'Get weather',
        params_schema: nil,
        parameters: [],
        provider_params: { function: { strict: true } }
      )

      result = described_class.tool_for(tool)

      expect(result[:function][:strict]).to eq(true)
    end

    it 'generates empty parameters schema for tools without params' do
      tool = instance_double(
        RubyLLM::Tool,
        name: 'simple_tool',
        description: 'A simple tool',
        params_schema: nil,
        parameters: [],
        provider_params: {}
      )

      result = described_class.tool_for(tool)

      expect(result[:function][:parameters]).to include(
        'type' => 'object',
        'properties' => {},
        'required' => []
      )
    end
  end

  describe '.format_tool_calls' do
    it 'formats tool calls for API request' do
      tool_calls = {
        'call_1' => RubyLLM::ToolCall.new(
          id: 'call_1',
          name: 'weather',
          arguments: { city: 'Berlin' }
        )
      }

      result = described_class.format_tool_calls(tool_calls)

      expect(result.length).to eq(1)
      expect(result[0][:id]).to eq('call_1')
      expect(result[0][:type]).to eq('function')
      expect(result[0][:function][:name]).to eq('weather')
      expect(result[0][:function][:arguments]).to eq('{"city":"Berlin"}')
    end

    it 'returns nil for empty tool calls' do
      expect(described_class.format_tool_calls(nil)).to be_nil
      expect(described_class.format_tool_calls({})).to be_nil
    end

    it 'handles multiple tool calls' do
      tool_calls = {
        'call_1' => RubyLLM::ToolCall.new(id: 'call_1', name: 'weather', arguments: {}),
        'call_2' => RubyLLM::ToolCall.new(id: 'call_2', name: 'time', arguments: {})
      }

      result = described_class.format_tool_calls(tool_calls)

      expect(result.length).to eq(2)
    end
  end

  describe '.parse_tool_calls' do
    it 'parses tool calls from API response' do
      raw_tool_calls = [
        {
          'id' => 'call_abc123',
          'function' => {
            'name' => 'weather',
            'arguments' => '{"city": "Tokyo"}'
          }
        }
      ]

      result = described_class.parse_tool_calls(raw_tool_calls)

      expect(result).to be_a(Hash)
      expect(result['call_abc123']).to be_a(RubyLLM::ToolCall)
      expect(result['call_abc123'].name).to eq('weather')
      expect(result['call_abc123'].arguments).to eq({ 'city' => 'Tokyo' })
    end

    it 'returns nil for empty tool calls' do
      expect(described_class.parse_tool_calls(nil)).to be_nil
      expect(described_class.parse_tool_calls([])).to be_nil
    end

    it 'handles empty arguments' do
      raw_tool_calls = [
        {
          'id' => 'call_1',
          'function' => {
            'name' => 'simple',
            'arguments' => ''
          }
        }
      ]

      result = described_class.parse_tool_calls(raw_tool_calls)

      expect(result['call_1'].arguments).to eq({})
    end

    it 'handles nil arguments' do
      raw_tool_calls = [
        {
          'id' => 'call_1',
          'function' => {
            'name' => 'simple',
            'arguments' => nil
          }
        }
      ]

      result = described_class.parse_tool_calls(raw_tool_calls)

      expect(result['call_1'].arguments).to eq({})
    end

    it 'skips argument parsing when parse_arguments is false' do
      raw_tool_calls = [
        {
          'id' => 'call_1',
          'function' => {
            'name' => 'weather',
            'arguments' => '{"city": "Berlin"}'
          }
        }
      ]

      result = described_class.parse_tool_calls(raw_tool_calls, parse_arguments: false)

      expect(result['call_1'].arguments).to eq('{"city": "Berlin"}')
    end
  end
end
