# frozen_string_literal: true

module RubyLLM
  module Providers
    # Pollinations API integration.
    # Supports chat, image/video generation, audio (TTS/music), and transcription.
    class Pollinations < Provider
      def api_base
        @config.pollinations_api_base || 'https://text.pollinations.ai'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.pollinations_api_key}",
          'Content-Type' => 'application/json'
        }.compact
      end

      class << self
        def capabilities
          Pollinations::Capabilities
        end

        def configuration_requirements
          %i[pollinations_api_key]
        end
      end
    end
  end
end
