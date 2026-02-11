# frozen_string_literal: true

module RubyLLM
  module Providers
    # Pollinations API integration.
    # Supports chat, image/video generation, audio (TTS/music), and transcription.
    class Pollinations < Provider
      include Pollinations::Chat
      include Pollinations::Media
      include Pollinations::Streaming
      include Pollinations::Tools
      include Pollinations::Images

      IMAGE_API_BASE = 'https://image.pollinations.ai'

      def api_base
        @config.pollinations_api_base || 'https://text.pollinations.ai'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.pollinations_api_key}",
          'Content-Type' => 'application/json'
        }.compact
      end

      def paint(prompt, model:, size:)
        payload = render_image_payload(prompt, model: model, size: size)
        url = images_url(prompt, **payload)
        response = image_connection.get(url)
        parse_image_response(response, model: model)
      end

      class << self
        def capabilities
          Pollinations::Capabilities
        end

        def configuration_requirements
          %i[pollinations_api_key]
        end
      end

      private

      def image_connection
        @image_connection ||= Faraday.new(IMAGE_API_BASE) do |faraday|
          faraday.options.timeout = @config.request_timeout || 600
          faraday.response :logger, RubyLLM.logger, bodies: false, log_level: :debug
          faraday.request :retry, max: @config.max_retries || 3, retry_statuses: [429, 500, 502, 503, 504]
          faraday.adapter :net_http
          faraday.headers['Authorization'] = "Bearer #{@config.pollinations_api_key}"
        end
      end
    end
  end
end
