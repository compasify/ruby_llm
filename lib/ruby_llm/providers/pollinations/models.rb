# frozen_string_literal: true

module RubyLLM
  module Providers
    class Pollinations
      # Models fetching and parsing for the Pollinations API integration.
      # Fetches from /v1/models (OpenAI-compatible format).
      module Models
        module_function

        def models_url
          'v1/models'
        end

        def parse_list_models_response(response, slug, capabilities)
          Array(response.body['data']).map do |model_data|
            build_model_info(model_data, slug, capabilities)
          end
        end

        def build_model_info(model_data, slug, capabilities)
          model_id = model_data['id']

          Model::Info.new(
            id: model_id,
            name: capabilities.format_display_name(model_id),
            provider: slug,
            family: capabilities.model_family(model_id),
            created_at: parse_created_at(model_data['created']),
            context_window: capabilities.context_window_for(model_id),
            max_output_tokens: capabilities.max_tokens_for(model_id),
            modalities: capabilities.modalities_for(model_id),
            capabilities: capabilities.capabilities_for(model_id),
            pricing: capabilities.pricing_for(model_id),
            metadata: build_metadata(model_data)
          )
        end

        def parse_created_at(created)
          return nil unless created

          Time.at(created)
        end

        def build_metadata(model_data)
          {
            object: model_data['object'],
            owned_by: model_data['owned_by']
          }.compact
        end
      end
    end
  end
end
