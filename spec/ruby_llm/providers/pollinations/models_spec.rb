# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Pollinations::Models do
  describe '.models_url' do
    it 'returns correct endpoint path' do
      expect(described_class.models_url).to eq('v1/models')
    end
  end

  describe '.parse_list_models_response' do
    let(:capabilities) { RubyLLM::Providers::Pollinations::Capabilities }
    let(:slug) { 'pollinations' }

    it 'parses OpenAI-compatible model list' do
      response_body = {
        'data' => [
          { 'id' => 'openai', 'object' => 'model', 'created' => 1_700_000_000, 'owned_by' => 'pollinations' },
          { 'id' => 'gemini', 'object' => 'model', 'created' => 1_700_000_001, 'owned_by' => 'pollinations' }
        ]
      }
      response = instance_double(Faraday::Response, body: response_body)

      models = described_class.parse_list_models_response(response, slug, capabilities)

      expect(models.length).to eq(2)
      expect(models.first).to be_a(RubyLLM::Model::Info)
      expect(models.first.id).to eq('openai')
      expect(models.last.id).to eq('gemini')
    end

    it 'sets provider correctly' do
      response_body = { 'data' => [{ 'id' => 'openai' }] }
      response = instance_double(Faraday::Response, body: response_body)

      models = described_class.parse_list_models_response(response, slug, capabilities)

      expect(models.first.provider).to eq('pollinations')
    end

    it 'sets family based on model id' do
      response_body = {
        'data' => [
          { 'id' => 'openai' },
          { 'id' => 'gemini' },
          { 'id' => 'claude' },
          { 'id' => 'flux' }
        ]
      }
      response = instance_double(Faraday::Response, body: response_body)

      models = described_class.parse_list_models_response(response, slug, capabilities)

      expect(models[0].family).to eq('openai')
      expect(models[1].family).to eq('gemini')
      expect(models[2].family).to eq('claude')
      expect(models[3].family).to eq('image')
    end

    it 'handles empty data array' do
      response_body = { 'data' => [] }
      response = instance_double(Faraday::Response, body: response_body)

      models = described_class.parse_list_models_response(response, slug, capabilities)

      expect(models).to eq([])
    end

    it 'handles nil data' do
      response_body = { 'data' => nil }
      response = instance_double(Faraday::Response, body: response_body)

      models = described_class.parse_list_models_response(response, slug, capabilities)

      expect(models).to eq([])
    end

    it 'parses created_at timestamp' do
      timestamp = 1_700_000_000
      response_body = { 'data' => [{ 'id' => 'openai', 'created' => timestamp }] }
      response = instance_double(Faraday::Response, body: response_body)

      models = described_class.parse_list_models_response(response, slug, capabilities)

      expect(models.first.created_at).to eq(Time.at(timestamp))
    end

    it 'handles missing created timestamp' do
      response_body = { 'data' => [{ 'id' => 'openai' }] }
      response = instance_double(Faraday::Response, body: response_body)

      models = described_class.parse_list_models_response(response, slug, capabilities)

      expect(models.first.created_at).to be_nil
    end

    it 'includes metadata' do
      response_body = {
        'data' => [{ 'id' => 'openai', 'object' => 'model', 'owned_by' => 'pollinations' }]
      }
      response = instance_double(Faraday::Response, body: response_body)

      models = described_class.parse_list_models_response(response, slug, capabilities)

      expect(models.first.metadata[:object]).to eq('model')
      expect(models.first.metadata[:owned_by]).to eq('pollinations')
    end
  end

  describe '.build_model_info' do
    let(:capabilities) { RubyLLM::Providers::Pollinations::Capabilities }
    let(:slug) { 'pollinations' }

    it 'builds Model::Info with all fields' do
      model_data = {
        'id' => 'gemini-large',
        'object' => 'model',
        'created' => 1_700_000_000,
        'owned_by' => 'pollinations'
      }

      info = described_class.build_model_info(model_data, slug, capabilities)

      expect(info.id).to eq('gemini-large')
      expect(info.name).to eq('Gemini Large')
      expect(info.provider).to eq('pollinations')
      expect(info.family).to eq('gemini')
      expect(info.context_window).to eq(1_000_000)
      expect(info.max_output_tokens).to eq(8_192)
    end

    it 'sets modalities for chat models' do
      model_data = { 'id' => 'openai' }
      info = described_class.build_model_info(model_data, slug, capabilities)

      expect(info.modalities.input).to include('text')
      expect(info.modalities.input).to include('image')
      expect(info.modalities.output).to include('text')
    end

    it 'sets modalities for image models' do
      model_data = { 'id' => 'flux' }
      info = described_class.build_model_info(model_data, slug, capabilities)

      expect(info.modalities.input).to include('text')
      expect(info.modalities.output).to include('image')
    end

    it 'sets capabilities for chat models' do
      model_data = { 'id' => 'openai' }
      info = described_class.build_model_info(model_data, slug, capabilities)

      expect(info.capabilities).to include('streaming')
      expect(info.capabilities).to include('function_calling')
      expect(info.capabilities).to include('structured_output')
    end
  end
end

RSpec.describe RubyLLM::Providers::Pollinations::Capabilities do
  describe '.model_family' do
    it 'detects openai family' do
      expect(described_class.model_family('openai')).to eq('openai')
      expect(described_class.model_family('openai-fast')).to eq('openai')
      expect(described_class.model_family('openai-large')).to eq('openai')
    end

    it 'detects gemini family' do
      expect(described_class.model_family('gemini')).to eq('gemini')
      expect(described_class.model_family('gemini-fast')).to eq('gemini')
      expect(described_class.model_family('gemini-large')).to eq('gemini')
    end

    it 'detects claude family' do
      expect(described_class.model_family('claude')).to eq('claude')
      expect(described_class.model_family('claude-fast')).to eq('claude')
      expect(described_class.model_family('claude-large')).to eq('claude')
    end

    it 'detects image family' do
      expect(described_class.model_family('flux')).to eq('image')
      expect(described_class.model_family('zimage')).to eq('image')
      expect(described_class.model_family('gptimage')).to eq('image')
      expect(described_class.model_family('seedream')).to eq('image')
      expect(described_class.model_family('nanobanana')).to eq('image')
    end

    it 'detects video family' do
      expect(described_class.model_family('veo')).to eq('video')
      expect(described_class.model_family('seedance')).to eq('video')
      expect(described_class.model_family('seedance-pro')).to eq('video')
      expect(described_class.model_family('grok-video')).to eq('video')
      expect(described_class.model_family('ltx-2')).to eq('video')
    end

    it 'detects transcription family' do
      expect(described_class.model_family('whisper-large-v3')).to eq('transcription')
      expect(described_class.model_family('whisper-1')).to eq('transcription')
    end

    it 'detects audio family' do
      expect(described_class.model_family('tts-1')).to eq('audio')
      expect(described_class.model_family('elevenmusic')).to eq('audio')
      expect(described_class.model_family('music')).to eq('audio')
    end

    it 'returns other for unknown models' do
      expect(described_class.model_family('unknown-model')).to eq('other')
    end
  end

  describe '.model_type' do
    it 'returns image for image and video families' do
      expect(described_class.model_type('flux')).to eq('image')
      expect(described_class.model_type('veo')).to eq('image')
    end

    it 'returns audio for transcription and audio families' do
      expect(described_class.model_type('whisper-1')).to eq('audio')
      expect(described_class.model_type('tts-1')).to eq('audio')
    end

    it 'returns chat for chat model families' do
      expect(described_class.model_type('openai')).to eq('chat')
      expect(described_class.model_type('gemini')).to eq('chat')
      expect(described_class.model_type('claude')).to eq('chat')
    end
  end

  describe '.context_window_for' do
    it 'returns 1M for gemini' do
      expect(described_class.context_window_for('gemini')).to eq(1_000_000)
    end

    it 'returns 200K for claude' do
      expect(described_class.context_window_for('claude')).to eq(200_000)
    end

    it 'returns default for openai' do
      expect(described_class.context_window_for('openai')).to eq(128_000)
    end
  end

  describe '.supports_vision?' do
    it 'returns true for chat model families' do
      expect(described_class.supports_vision?('openai')).to be true
      expect(described_class.supports_vision?('gemini')).to be true
      expect(described_class.supports_vision?('claude')).to be true
    end

    it 'returns false for non-chat models' do
      expect(described_class.supports_vision?('flux')).to be false
      expect(described_class.supports_vision?('whisper-1')).to be false
    end
  end

  describe '.supports_functions?' do
    it 'returns true for chat model families' do
      expect(described_class.supports_functions?('openai')).to be true
      expect(described_class.supports_functions?('gemini')).to be true
      expect(described_class.supports_functions?('claude')).to be true
    end

    it 'returns false for non-chat models' do
      expect(described_class.supports_functions?('flux')).to be false
    end
  end

  describe '.format_display_name' do
    it 'formats model id as display name' do
      expect(described_class.format_display_name('openai-fast')).to eq('Openai Fast')
      expect(described_class.format_display_name('gemini-large')).to eq('Gemini Large')
      expect(described_class.format_display_name('whisper-large-v3')).to eq('Whisper Large V3')
    end
  end

  describe '.modalities_for' do
    it 'returns text input/output for chat' do
      modalities = described_class.modalities_for('openai')
      expect(modalities[:input]).to include('text')
      expect(modalities[:output]).to include('text')
    end

    it 'includes image input for vision models' do
      modalities = described_class.modalities_for('gemini')
      expect(modalities[:input]).to include('image')
    end

    it 'returns image output for image models' do
      modalities = described_class.modalities_for('flux')
      expect(modalities[:output]).to include('image')
    end

    it 'returns audio output for audio models' do
      modalities = described_class.modalities_for('tts-1')
      expect(modalities[:output]).to include('audio')
    end
  end

  describe '.capabilities_for' do
    it 'includes streaming for chat models' do
      expect(described_class.capabilities_for('openai')).to include('streaming')
    end

    it 'includes function_calling for supported models' do
      expect(described_class.capabilities_for('openai')).to include('function_calling')
    end

    it 'includes structured_output for supported models' do
      expect(described_class.capabilities_for('gemini')).to include('structured_output')
    end

    it 'excludes streaming for image models' do
      expect(described_class.capabilities_for('flux')).not_to include('streaming')
    end
  end
end
