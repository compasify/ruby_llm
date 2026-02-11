# frozen_string_literal: true

module RubyLLM
  module Providers
    class Pollinations
      # Image/video generation methods for the Pollinations API integration.
      # Uses GET /image/{prompt} endpoint with query params.
      # Supports both image and video generation depending on model.
      module Images
        module_function

        VIDEO_MODELS = %w[veo seedance seedance-pro grok-video ltx-2].freeze
        DEFAULT_IMAGE_MODEL = 'flux'

        def images_url(prompt, **options)
          encoded_prompt = ERB::Util.url_encode(prompt)
          params = build_image_params(options)
          query_string = params.empty? ? '' : "?#{URI.encode_www_form(params)}"
          "prompt/#{encoded_prompt}#{query_string}"
        end

        def render_image_payload(prompt, model:, size:)
          width, height = parse_size(size)
          {
            prompt: prompt,
            model: model || DEFAULT_IMAGE_MODEL,
            width: width,
            height: height
          }
        end

        def parse_image_response(response, model:)
          content_type = response.headers['content-type'] || ''
          is_video = video_response?(content_type, model)
          mime_type = extract_mime_type(content_type, is_video)
          data = Base64.strict_encode64(response.body)

          Image.new(
            data: data,
            mime_type: mime_type,
            model_id: model
          )
        end

        def video_model?(model)
          VIDEO_MODELS.include?(model.to_s.downcase)
        end

        def video_response?(content_type, model)
          content_type.include?('video/') || video_model?(model)
        end

        BASIC_PARAMS = %i[model width height seed quality].freeze
        BOOLEAN_PARAMS = %i[safe enhance].freeze

        def build_image_params(options)
          params = extract_basic_params(options)
          extract_boolean_params(params, options)
          params[:negative_prompt] = options[:negative_prompt] if options[:negative_prompt]
          add_video_params(params, options) if options[:model] && video_model?(options[:model])
          params
        end

        def extract_basic_params(options)
          BASIC_PARAMS.each_with_object({}) do |key, params|
            params[key] = options[key] if options[key]
          end
        end

        def extract_boolean_params(params, options)
          BOOLEAN_PARAMS.each do |key|
            params[key] = options[key] if options.key?(key)
          end
        end

        def add_video_params(params, options)
          params[:duration] = options[:duration] if options[:duration]
          params[:aspectRatio] = options[:aspect_ratio] if options[:aspect_ratio]
          params[:audio] = options[:audio] if options.key?(:audio)
          params[:image] = options[:image] if options[:image]
        end

        def parse_size(size)
          return [1024, 1024] unless size

          parts = size.to_s.split('x')
          return [1024, 1024] unless parts.length == 2

          [parts[0].to_i, parts[1].to_i]
        end

        def extract_mime_type(content_type, is_video)
          return 'video/mp4' if is_video && !content_type.include?('video/')
          return content_type.split(';').first.strip unless content_type.empty?

          is_video ? 'video/mp4' : 'image/jpeg'
        end
      end
    end
  end
end
