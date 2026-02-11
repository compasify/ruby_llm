# frozen_string_literal: true

module RubyLLM
  module Providers
    class Pollinations
      # Audio generation methods for the Pollinations API integration.
      # Uses POST /v1/audio/speech endpoint (OpenAI-compatible).
      # Supports TTS with multiple voices and music generation (model=elevenmusic/music).
      module Audio
        module_function

        MUSIC_MODELS = %w[elevenmusic music].freeze
        DEFAULT_VOICE = 'alloy'
        DEFAULT_FORMAT = 'mp3'
        DEFAULT_SPEED = 1.0
        MAX_INPUT_LENGTH = 4096

        VOICE_ENUM = %w[
          alloy echo fable onyx shimmer coral verse ballad ash sage amuch dan
          rachel bella
        ].freeze

        FORMAT_ENUM = %w[mp3 opus aac flac wav pcm].freeze

        def speech_url
          'v1/audio/speech'
        end

        def render_speech_payload(input, model:, voice:, **options)
          validate_speech_input!(input)
          build_speech_payload(input, model, voice, options)
        end

        def validate_speech_input!(input)
          raise ArgumentError, 'Input text is required' if input.nil? || input.to_s.empty?
          return unless input.length > MAX_INPUT_LENGTH

          raise ArgumentError, "Input exceeds maximum length of #{MAX_INPUT_LENGTH} characters"
        end

        def build_speech_payload(input, model, voice, options)
          payload = {
            input: input,
            model: model,
            voice: voice || DEFAULT_VOICE,
            response_format: options[:response_format] || DEFAULT_FORMAT,
            speed: options[:speed] || DEFAULT_SPEED
          }
          add_music_options(payload, model, options)
          payload.compact
        end

        def add_music_options(payload, model, options)
          return unless music_model?(model)

          payload[:duration] = options[:duration] if options[:duration]
          payload[:instrumental] = options[:instrumental] if options.key?(:instrumental)
        end

        def parse_speech_response(response, model:)
          content_type = response.headers['content-type'] || ''
          mime_type = content_type.empty? ? 'audio/mpeg' : content_type.split(';').first.strip
          data = Base64.strict_encode64(response.body)

          AudioOutput.new(
            data: data,
            mime_type: mime_type,
            model_id: model
          )
        end

        def music_model?(model)
          return false unless model

          MUSIC_MODELS.include?(model.to_s.downcase)
        end
      end
    end
  end
end
