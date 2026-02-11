# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Pollinations::Transcription do
  describe '.transcription_url' do
    it 'returns correct endpoint path' do
      expect(described_class.transcription_url).to eq('v1/audio/transcriptions')
    end
  end

  describe '.render_transcription_payload' do
    let(:file_part) { instance_double(Faraday::Multipart::FilePart) }

    it 'builds payload with required params' do
      payload = described_class.render_transcription_payload(
        file_part,
        model: 'whisper-large-v3',
        language: 'en'
      )

      expect(payload[:file]).to eq(file_part)
      expect(payload[:model]).to eq('whisper-large-v3')
      expect(payload[:language]).to eq('en')
      expect(payload[:response_format]).to eq('json')
    end

    it 'uses default model when nil' do
      payload = described_class.render_transcription_payload(
        file_part,
        model: nil,
        language: 'en'
      )

      expect(payload[:model]).to eq('whisper-large-v3')
    end

    it 'includes optional prompt' do
      payload = described_class.render_transcription_payload(
        file_part,
        model: 'whisper-1',
        language: 'en',
        prompt: 'Technical discussion about AI'
      )

      expect(payload[:prompt]).to eq('Technical discussion about AI')
    end

    it 'includes optional temperature' do
      payload = described_class.render_transcription_payload(
        file_part,
        model: 'whisper-1',
        language: nil,
        temperature: 0.5
      )

      expect(payload[:temperature]).to eq(0.5)
    end

    it 'includes custom response_format' do
      payload = described_class.render_transcription_payload(
        file_part,
        model: 'whisper-1',
        language: nil,
        response_format: 'srt'
      )

      expect(payload[:response_format]).to eq('srt')
    end

    it 'omits nil language' do
      payload = described_class.render_transcription_payload(
        file_part,
        model: 'whisper-1',
        language: nil
      )

      expect(payload).not_to have_key(:language)
    end
  end

  describe '.parse_transcription_response' do
    context 'with JSON response' do
      it 'returns Transcription with parsed data' do
        body = {
          'text' => 'Hello world',
          'language' => 'en',
          'duration' => 5.5,
          'segments' => [{ 'text' => 'Hello world', 'start' => 0.0, 'end' => 5.5 }]
        }
        response = instance_double(Faraday::Response, body: body)

        transcription = described_class.parse_transcription_response(response, model: 'whisper-large-v3')

        expect(transcription).to be_a(RubyLLM::Transcription)
        expect(transcription.text).to eq('Hello world')
        expect(transcription.model).to eq('whisper-large-v3')
        expect(transcription.language).to eq('en')
        expect(transcription.duration).to eq(5.5)
        expect(transcription.segments).to eq([{ 'text' => 'Hello world', 'start' => 0.0, 'end' => 5.5 }])
      end

      it 'handles minimal JSON response' do
        body = { 'text' => 'Just text' }
        response = instance_double(Faraday::Response, body: body)

        transcription = described_class.parse_transcription_response(response, model: 'whisper-1')

        expect(transcription.text).to eq('Just text')
        expect(transcription.language).to be_nil
        expect(transcription.duration).to be_nil
        expect(transcription.segments).to be_nil
      end
    end

    context 'with plain text response' do
      it 'returns Transcription with text only' do
        body = 'Plain text transcription result'
        response = instance_double(Faraday::Response, body: body)

        transcription = described_class.parse_transcription_response(response, model: 'whisper-1')

        expect(transcription.text).to eq('Plain text transcription result')
        expect(transcription.model).to eq('whisper-1')
      end
    end

    context 'with SRT format response' do
      it 'returns Transcription with raw SRT text' do
        body = "1\n00:00:00,000 --> 00:00:05,000\nHello world"
        response = instance_double(Faraday::Response, body: body)

        transcription = described_class.parse_transcription_response(response, model: 'whisper-1')

        expect(transcription.text).to include('Hello world')
      end
    end
  end
end
