# frozen_string_literal: true

module RubyLLM
  module Providers
    class Pollinations
      # Audio transcription methods for the Pollinations API integration.
      # Uses POST /v1/audio/transcriptions endpoint (OpenAI Whisper compatible).
      module Transcription
        module_function

        SUPPORTED_MODELS = %w[whisper-large-v3 whisper-1].freeze
        DEFAULT_MODEL = 'whisper-large-v3'
        RESPONSE_FORMATS = %w[json text srt verbose_json vtt].freeze

        def transcription_url
          'v1/audio/transcriptions'
        end

        def render_transcription_payload(file_part, model:, language:, **options)
          {
            file: file_part,
            model: model || DEFAULT_MODEL,
            language: language,
            prompt: options[:prompt],
            response_format: options[:response_format] || 'json',
            temperature: options[:temperature]
          }.compact
        end

        def parse_transcription_response(response, model:)
          data = response.body
          return RubyLLM::Transcription.new(text: data, model: model) if data.is_a?(String)

          RubyLLM::Transcription.new(
            text: data['text'],
            model: model,
            language: data['language'],
            duration: data['duration'],
            segments: data['segments']
          )
        end
      end
    end
  end
end
