# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Pollinations::Account do
  let(:config) do
    instance_double(
      RubyLLM::Configuration,
      pollinations_api_key: 'test-key',
      pollinations_api_base: nil,
      request_timeout: 300,
      max_retries: 3,
      retry_interval: 0.1,
      retry_backoff_factor: 2,
      retry_interval_randomness: 0.5,
      http_proxy: nil
    )
  end

  let(:provider) { RubyLLM::Providers::Pollinations.new(config) }
  let(:connection) { instance_double(RubyLLM::Connection) }

  let(:mock_request) { instance_double(Faraday::Request, params: {}) }

  before do
    allow(provider).to receive(:connection).and_return(connection)
    provider.instance_variable_set(:@connection, connection)
  end

  describe '#profile' do
    it 'returns normalized profile data' do
      response_body = {
        'name' => 'Test User',
        'email' => 'test@example.com',
        'githubUsername' => 'testuser',
        'image' => 'https://example.com/avatar.png',
        'tier' => 'seed',
        'createdAt' => '2024-01-01T00:00:00Z',
        'nextResetAt' => '2024-02-01T00:00:00Z'
      }
      response = instance_double(Faraday::Response, body: response_body)
      allow(connection).to receive(:get).with('account/profile').and_return(response)

      result = provider.profile

      expect(result[:name]).to eq('Test User')
      expect(result[:email]).to eq('test@example.com')
      expect(result[:github_username]).to eq('testuser')
      expect(result[:tier]).to eq('seed')
      expect(result[:created_at]).to be_a(Time)
    end

    it 'handles nil values' do
      response_body = {
        'name' => nil,
        'email' => nil,
        'tier' => 'anonymous'
      }
      response = instance_double(Faraday::Response, body: response_body)
      allow(connection).to receive(:get).with('account/profile').and_return(response)

      result = provider.profile

      expect(result[:name]).to be_nil
      expect(result[:email]).to be_nil
      expect(result[:tier]).to eq('anonymous')
    end
  end

  describe '#balance' do
    it 'returns balance hash' do
      response_body = { 'balance' => 1234.56 }
      response = instance_double(Faraday::Response, body: response_body)
      allow(connection).to receive(:get).with('account/balance').and_return(response)

      result = provider.balance

      expect(result).to eq({ balance: 1234.56 })
    end

    it 'handles zero balance' do
      response_body = { 'balance' => 0 }
      response = instance_double(Faraday::Response, body: response_body)
      allow(connection).to receive(:get).with('account/balance').and_return(response)

      result = provider.balance

      expect(result).to eq({ balance: 0 })
    end
  end

  describe '#usage' do
    it 'returns usage data with default params' do
      response_body = {
        'usage' => [
          { 'timestamp' => '2024-01-01', 'type' => 'generate.text', 'cost_usd' => 0.01 }
        ],
        'count' => 1
      }
      response = instance_double(Faraday::Response, body: response_body)
      allow(connection).to receive(:get).with('account/usage').and_yield(mock_request).and_return(response)

      result = provider.usage

      expect(result[:usage]).to be_an(Array)
      expect(result[:usage].first['type']).to eq('generate.text')
      expect(result[:count]).to eq(1)
    end

    it 'passes custom limit' do
      response_body = { 'usage' => [], 'count' => 0 }
      response = instance_double(Faraday::Response, body: response_body)
      allow(connection).to receive(:get).with('account/usage').and_yield(mock_request).and_return(response)

      provider.usage(limit: 10)
    end

    it 'passes before param' do
      response_body = { 'usage' => [], 'count' => 0 }
      response = instance_double(Faraday::Response, body: response_body)
      allow(connection).to receive(:get).with('account/usage').and_yield(mock_request).and_return(response)

      provider.usage(before: 'cursor123')
    end

    it 'returns raw data for csv format' do
      csv_data = "timestamp,type,cost\n2024-01-01,text,0.01"
      response = instance_double(Faraday::Response, body: csv_data)
      allow(connection).to receive(:get).with('account/usage').and_yield(mock_request).and_return(response)

      result = provider.usage(format: :csv)

      expect(result).to eq(csv_data)
    end
  end

  describe '#usage_daily' do
    it 'returns daily usage data' do
      response_body = {
        'usage' => [
          { 'date' => '2024-01-01', 'model' => 'openai', 'requests' => 100, 'cost_usd' => 1.0 }
        ],
        'count' => 1
      }
      response = instance_double(Faraday::Response, body: response_body)
      allow(connection).to receive(:get).with('account/usage/daily').and_yield(mock_request).and_return(response)

      result = provider.usage_daily

      expect(result[:usage]).to be_an(Array)
      expect(result[:usage].first['date']).to eq('2024-01-01')
      expect(result[:count]).to eq(1)
    end

    it 'returns raw data for csv format' do
      csv_data = "date,model,requests,cost\n2024-01-01,openai,100,1.0"
      response = instance_double(Faraday::Response, body: csv_data)
      allow(connection).to receive(:get).with('account/usage/daily').and_yield(mock_request).and_return(response)

      result = provider.usage_daily(format: :csv)

      expect(result).to eq(csv_data)
    end
  end

  describe '#key_info' do
    it 'returns normalized key info' do
      response_body = {
        'valid' => true,
        'type' => 'secret',
        'name' => 'My API Key',
        'expiresAt' => '2025-01-01T00:00:00Z',
        'expiresIn' => 86_400,
        'permissions' => {
          'models' => %w[openai gemini],
          'account' => %w[balance usage]
        },
        'pollenBudget' => 10_000,
        'rateLimitEnabled' => false
      }
      response = instance_double(Faraday::Response, body: response_body)
      allow(connection).to receive(:get).with('account/key').and_return(response)

      result = provider.key_info

      expect(result[:valid]).to be true
      expect(result[:type]).to eq('secret')
      expect(result[:name]).to eq('My API Key')
      expect(result[:expires_at]).to be_a(Time)
      expect(result[:expires_in]).to eq(86_400)
      expect(result[:permissions][:models]).to eq(%w[openai gemini])
      expect(result[:pollen_budget]).to eq(10_000)
      expect(result[:rate_limit_enabled]).to be false
    end

    it 'handles publishable key' do
      response_body = {
        'valid' => true,
        'type' => 'publishable',
        'rateLimitEnabled' => true
      }
      response = instance_double(Faraday::Response, body: response_body)
      allow(connection).to receive(:get).with('account/key').and_return(response)

      result = provider.key_info

      expect(result[:type]).to eq('publishable')
      expect(result[:rate_limit_enabled]).to be true
    end

    it 'handles nil permissions' do
      response_body = {
        'valid' => true,
        'type' => 'secret',
        'permissions' => nil
      }
      response = instance_double(Faraday::Response, body: response_body)
      allow(connection).to receive(:get).with('account/key').and_return(response)

      result = provider.key_info

      expect(result[:permissions]).to be_nil
    end
  end
end
