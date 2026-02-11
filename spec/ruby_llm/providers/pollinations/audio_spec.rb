# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe RubyLLM::Providers::Pollinations::Audio do
  describe '.speech_url' do
    it 'returns correct endpoint path' do
      expect(described_class.speech_url).to eq('v1/audio/speech')
    end
  end

  describe '.render_speech_payload' do
    it 'builds basic payload with required params' do
      payload = described_class.render_speech_payload('Hello world', model: 'tts-1', voice: 'alloy')

      expect(payload[:input]).to eq('Hello world')
      expect(payload[:model]).to eq('tts-1')
      expect(payload[:voice]).to eq('alloy')
      expect(payload[:response_format]).to eq('mp3')
      expect(payload[:speed]).to eq(1.0)
    end

    it 'uses default voice when nil' do
      payload = described_class.render_speech_payload('Hello', model: 'tts-1', voice: nil)
      expect(payload[:voice]).to eq('alloy')
    end

    it 'includes custom response_format' do
      payload = described_class.render_speech_payload('Hello', model: 'tts-1', voice: 'echo',
                                                               response_format: 'opus')
      expect(payload[:response_format]).to eq('opus')
    end

    it 'includes custom speed' do
      payload = described_class.render_speech_payload('Hello', model: 'tts-1', voice: 'echo', speed: 1.5)
      expect(payload[:speed]).to eq(1.5)
    end

    it 'includes music params for music model' do
      payload = described_class.render_speech_payload(
        'Upbeat electronic track',
        model: 'elevenmusic',
        voice: nil,
        duration: 120,
        instrumental: true
      )

      expect(payload[:duration]).to eq(120)
      expect(payload[:instrumental]).to eq(true)
    end

    it 'does not include music params for TTS model' do
      payload = described_class.render_speech_payload(
        'Hello',
        model: 'tts-1',
        voice: 'alloy',
        duration: 120
      )

      expect(payload).not_to have_key(:duration)
    end

    it 'raises error for empty input' do
      expect do
        described_class.render_speech_payload('', model: 'tts-1', voice: 'alloy')
      end.to raise_error(ArgumentError, /Input text is required/)
    end

    it 'raises error for nil input' do
      expect do
        described_class.render_speech_payload(nil, model: 'tts-1', voice: 'alloy')
      end.to raise_error(ArgumentError, /Input text is required/)
    end

    it 'raises error for input exceeding max length' do
      long_input = 'a' * 4097
      expect do
        described_class.render_speech_payload(long_input, model: 'tts-1', voice: 'alloy')
      end.to raise_error(ArgumentError, /exceeds maximum length/)
    end

    it 'accepts input at max length boundary' do
      max_input = 'a' * 4096
      expect do
        described_class.render_speech_payload(max_input, model: 'tts-1', voice: 'alloy')
      end.not_to raise_error
    end
  end

  describe '.parse_speech_response' do
    it 'returns AudioOutput with base64 data' do
      body = 'fake audio binary data'
      headers = { 'content-type' => 'audio/mpeg' }
      response = instance_double(Faraday::Response, body: body, headers: headers)

      audio = described_class.parse_speech_response(response, model: 'tts-1')

      expect(audio).to be_a(RubyLLM::AudioOutput)
      expect(audio.data).to eq(Base64.strict_encode64(body))
      expect(audio.mime_type).to eq('audio/mpeg')
      expect(audio.model_id).to eq('tts-1')
    end

    it 'handles opus format' do
      body = 'opus audio data'
      headers = { 'content-type' => 'audio/opus' }
      response = instance_double(Faraday::Response, body: body, headers: headers)

      audio = described_class.parse_speech_response(response, model: 'tts-1')

      expect(audio.mime_type).to eq('audio/opus')
    end

    it 'handles wav format' do
      body = 'wav audio data'
      headers = { 'content-type' => 'audio/wav' }
      response = instance_double(Faraday::Response, body: body, headers: headers)

      audio = described_class.parse_speech_response(response, model: 'tts-1')

      expect(audio.mime_type).to eq('audio/wav')
    end

    it 'defaults to audio/mpeg when content-type is empty' do
      body = 'audio data'
      headers = { 'content-type' => '' }
      response = instance_double(Faraday::Response, body: body, headers: headers)

      audio = described_class.parse_speech_response(response, model: 'tts-1')

      expect(audio.mime_type).to eq('audio/mpeg')
    end

    it 'strips charset from content-type' do
      body = 'audio data'
      headers = { 'content-type' => 'audio/mpeg; charset=utf-8' }
      response = instance_double(Faraday::Response, body: body, headers: headers)

      audio = described_class.parse_speech_response(response, model: 'tts-1')

      expect(audio.mime_type).to eq('audio/mpeg')
    end
  end

  describe '.music_model?' do
    it 'returns true for elevenmusic' do
      expect(described_class.music_model?('elevenmusic')).to be true
    end

    it 'returns true for music alias' do
      expect(described_class.music_model?('music')).to be true
    end

    it 'returns false for TTS models' do
      expect(described_class.music_model?('tts-1')).to be false
      expect(described_class.music_model?('alloy')).to be false
    end

    it 'handles case insensitivity' do
      expect(described_class.music_model?('ELEVENMUSIC')).to be true
      expect(described_class.music_model?('Music')).to be true
    end

    it 'returns false for nil' do
      expect(described_class.music_model?(nil)).to be false
    end
  end
end

RSpec.describe RubyLLM::AudioOutput do
  describe '.new' do
    it 'initializes with all attributes' do
      audio = described_class.new(
        data: 'base64data',
        mime_type: 'audio/mpeg',
        model_id: 'tts-1',
        duration: 5.5
      )

      expect(audio.data).to eq('base64data')
      expect(audio.mime_type).to eq('audio/mpeg')
      expect(audio.model_id).to eq('tts-1')
      expect(audio.duration).to eq(5.5)
    end
  end

  describe '#base64?' do
    it 'returns true when data is present' do
      audio = described_class.new(data: 'base64data')
      expect(audio.base64?).to be true
    end

    it 'returns false when data is nil' do
      audio = described_class.new(data: nil)
      expect(audio.base64?).to be false
    end
  end

  describe '#to_blob' do
    it 'decodes base64 data' do
      original = 'hello audio world'
      encoded = Base64.strict_encode64(original)
      audio = described_class.new(data: encoded)

      expect(audio.to_blob).to eq(original)
    end

    it 'returns nil when no data' do
      audio = described_class.new(data: nil)
      expect(audio.to_blob).to be_nil
    end
  end

  describe '#save' do
    it 'writes binary data to file' do
      original = 'audio binary content'
      encoded = Base64.strict_encode64(original)
      audio = described_class.new(data: encoded)

      Dir.mktmpdir do |dir|
        path = File.join(dir, 'test.mp3')
        result = audio.save(path)

        expect(result).to eq(path)
        expect(File.binread(path)).to eq(original)
      end
    end
  end
end
