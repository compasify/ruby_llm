# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Pollinations do
  describe 'provider registration' do
    it 'is registered as :pollinations' do
      expect(RubyLLM::Provider.resolve(:pollinations)).to eq(described_class)
    end
  end

  describe '.configuration_requirements' do
    it 'requires pollinations_api_key' do
      expect(described_class.configuration_requirements).to eq(%i[pollinations_api_key])
    end
  end

  describe '.capabilities' do
    it 'returns Pollinations::Capabilities module' do
      expect(described_class.capabilities).to eq(RubyLLM::Providers::Pollinations::Capabilities)
    end
  end

  describe 'instance methods' do
    let(:config) do
      RubyLLM::Configuration.new.tap do |c|
        c.pollinations_api_key = 'sk_test_key'
      end
    end

    let(:provider) { described_class.new(config) }

    describe '#api_base' do
      it 'returns default Pollinations API base URL' do
        expect(provider.api_base).to eq('https://text.pollinations.ai')
      end

      it 'uses custom base when configured' do
        config.pollinations_api_base = 'https://custom.api.com'
        expect(provider.api_base).to eq('https://custom.api.com')
      end
    end

    describe '#headers' do
      it 'includes Authorization header with Bearer token' do
        expect(provider.headers['Authorization']).to eq('Bearer sk_test_key')
      end

      it 'includes Content-Type header' do
        expect(provider.headers['Content-Type']).to eq('application/json')
      end

      it 'does not include API key in query string format' do
        expect(provider.headers.values.join).not_to include('key=')
      end
    end
  end

  describe 'configuration validation' do
    it 'raises ConfigurationError when API key is missing' do
      config = RubyLLM::Configuration.new
      expect { described_class.new(config) }.to raise_error(
        RubyLLM::ConfigurationError,
        /Missing configuration for Pollinations: pollinations_api_key/
      )
    end
  end
end
