# frozen_string_literal: true

module RubyLLM
  module Providers
    class Pollinations
      # Determines capabilities and pricing for Pollinations models.
      module Capabilities
        module_function

        DEFAULT_CONTEXT_WINDOW = 128_000
        DEFAULT_MAX_TOKENS = 16_384
        CHAT_MODEL_FAMILIES = %w[gemini claude openai].freeze

        def model_family(model_id)
          case model_id
          when /^openai/ then 'openai'
          when /^gemini/ then 'gemini'
          when /^claude/ then 'claude'
          when /^flux|^zimage|^gptimage|^seedream|^nanobanana|^kontext|^imagen|^klein|^wan/ then 'image'
          when /^veo|^seedance|^grok-video|^ltx/ then 'video'
          when /^whisper/ then 'transcription'
          when /^tts|^elevenmusic|^music/ then 'audio'
          else 'other'
          end
        end

        def model_type(model_id)
          case model_family(model_id)
          when 'image', 'video' then 'image'
          when 'transcription', 'audio' then 'audio'
          else 'chat'
          end
        end

        def context_window_for(model_id)
          case model_family(model_id)
          when 'gemini' then 1_000_000
          when 'claude' then 200_000
          else DEFAULT_CONTEXT_WINDOW
          end
        end

        def max_tokens_for(model_id)
          case model_family(model_id)
          when 'gemini', 'claude' then 8_192
          else DEFAULT_MAX_TOKENS
          end
        end

        def supports_vision?(model_id)
          CHAT_MODEL_FAMILIES.include?(model_family(model_id))
        end

        def supports_functions?(model_id)
          CHAT_MODEL_FAMILIES.include?(model_family(model_id))
        end

        def supports_structured_output?(model_id)
          CHAT_MODEL_FAMILIES.include?(model_family(model_id))
        end

        def supports_json_mode?(model_id)
          supports_structured_output?(model_id)
        end

        def input_price_for(_model_id)
          0.0
        end

        def output_price_for(_model_id)
          0.0
        end

        def format_display_name(model_id)
          model_id.tr('-', ' ').split.map(&:capitalize).join(' ')
        end

        def modalities_for(model_id)
          case model_type(model_id)
          when 'image'
            { input: ['text'], output: ['image'] }
          when 'audio'
            { input: %w[text audio], output: ['audio'] }
          else
            modalities = { input: ['text'], output: ['text'] }
            modalities[:input] << 'image' if supports_vision?(model_id)
            modalities
          end
        end

        def capabilities_for(model_id)
          capabilities = []
          capabilities << 'streaming' if model_type(model_id) == 'chat'
          capabilities << 'function_calling' if supports_functions?(model_id)
          capabilities << 'structured_output' if supports_structured_output?(model_id)
          capabilities
        end

        def pricing_for(model_id)
          {
            text_tokens: {
              standard: {
                input_per_million: input_price_for(model_id),
                output_per_million: output_price_for(model_id)
              }
            }
          }
        end
      end
    end
  end
end
