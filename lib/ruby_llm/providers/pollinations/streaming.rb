# frozen_string_literal: true

module RubyLLM
  module Providers
    class Pollinations
      # Streaming methods of the Pollinations API integration
      module Streaming
        module_function

        def stream_url
          completion_url
        end

        def build_chunk(data)
          usage = data['usage'] || {}
          cached_tokens = usage.dig('prompt_tokens_details', 'cached_tokens')
          delta = data.dig('choices', 0, 'delta') || {}
          content_source = delta['content'] || data.dig('choices', 0, 'message', 'content')
          content, thinking_from_blocks = Pollinations::Chat.extract_content_and_thinking(content_source)

          Chunk.new(
            role: :assistant,
            model_id: data['model'],
            content: content,
            thinking: Thinking.build(
              text: thinking_from_blocks || delta['reasoning_content'] || delta['reasoning']
            ),
            tool_calls: Pollinations::Tools.parse_tool_calls(delta['tool_calls'], parse_arguments: false),
            input_tokens: usage['prompt_tokens'],
            output_tokens: usage['completion_tokens'],
            cached_tokens: cached_tokens,
            cache_creation_tokens: 0,
            thinking_tokens: usage.dig('completion_tokens_details', 'reasoning_tokens')
          )
        end

        def parse_streaming_error(data)
          error_data = JSON.parse(data)
          return unless error_data['error']

          error = error_data['error']
          code = error['code'] || error['type']

          case code
          when 'RATE_LIMIT', 'rate_limit_exceeded', 'insufficient_quota'
            [429, error['message']]
          when 'INTERNAL_ERROR', 'server_error'
            [500, error['message']]
          when 'UNAUTHORIZED'
            [401, error['message']]
          when 'PAYMENT_REQUIRED'
            [402, error['message']]
          else
            [400, error['message']]
          end
        end
      end
    end
  end
end
