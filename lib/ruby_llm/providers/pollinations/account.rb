# frozen_string_literal: true

module RubyLLM
  module Providers
    class Pollinations
      # Account and usage methods for the Pollinations API.
      # Provides access to balance, usage history, profile, and key info.
      module Account
        def profile
          response = @connection.get('account/profile')
          normalize_profile(response.body)
        end

        def balance
          response = @connection.get('account/balance')
          { balance: response.body['balance'] }
        end

        def usage(format: :json, limit: 100, before: nil)
          response = @connection.get('account/usage') do |req|
            req.params[:format] = format.to_s
            req.params[:limit] = limit
            req.params[:before] = before if before
          end
          normalize_usage(response.body, format)
        end

        def usage_daily(format: :json)
          response = @connection.get('account/usage/daily') do |req|
            req.params[:format] = format.to_s
          end
          normalize_usage(response.body, format)
        end

        def key_info
          response = @connection.get('account/key')
          normalize_key_info(response.body)
        end

        private

        def normalize_profile(data)
          {
            name: data['name'],
            email: data['email'],
            github_username: data['githubUsername'],
            image: data['image'],
            tier: data['tier'],
            created_at: parse_timestamp(data['createdAt']),
            next_reset_at: parse_timestamp(data['nextResetAt'])
          }
        end

        def normalize_usage(data, format)
          return data if format.to_sym == :csv

          {
            usage: data['usage'] || [],
            count: data['count']
          }
        end

        def normalize_key_info(data)
          {
            valid: data['valid'],
            type: data['type'],
            name: data['name'],
            expires_at: parse_timestamp(data['expiresAt']),
            expires_in: data['expiresIn'],
            permissions: normalize_permissions(data['permissions']),
            pollen_budget: data['pollenBudget'],
            rate_limit_enabled: data['rateLimitEnabled']
          }
        end

        def normalize_permissions(permissions)
          return nil unless permissions

          {
            models: permissions['models'],
            account: permissions['account']
          }
        end

        def parse_timestamp(value)
          return nil unless value

          Time.parse(value)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
