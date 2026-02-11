# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Pollinations::Images do
  describe '.images_url' do
    it 'builds URL with encoded prompt' do
      url = described_class.images_url('a cat', model: 'flux')
      expect(url).to start_with('prompt/a%20cat')
    end

    it 'includes model in query params' do
      url = described_class.images_url('test', model: 'flux')
      expect(url).to include('model=flux')
    end

    it 'includes size params' do
      url = described_class.images_url('test', model: 'flux', width: 512, height: 768)
      expect(url).to include('width=512')
      expect(url).to include('height=768')
    end

    it 'handles special characters in prompt' do
      url = described_class.images_url('a cat & dog!', model: 'flux')
      expect(url).to include('a%20cat%20%26%20dog%21')
    end

    it 'includes video params for video models' do
      url = described_class.images_url('test', model: 'veo', duration: 6, aspect_ratio: '16:9')
      expect(url).to include('duration=6')
      expect(url).to include('aspectRatio=16%3A9')
    end
  end

  describe '.render_image_payload' do
    it 'returns basic payload with model and size' do
      payload = described_class.render_image_payload('a sunset', model: 'flux', size: '1024x1024')

      expect(payload[:prompt]).to eq('a sunset')
      expect(payload[:model]).to eq('flux')
      expect(payload[:width]).to eq(1024)
      expect(payload[:height]).to eq(1024)
    end

    it 'uses default model when nil' do
      payload = described_class.render_image_payload('test', model: nil, size: '512x512')
      expect(payload[:model]).to eq('flux')
    end

    it 'parses custom sizes' do
      payload = described_class.render_image_payload('test', model: 'flux', size: '768x1024')
      expect(payload[:width]).to eq(768)
      expect(payload[:height]).to eq(1024)
    end

    it 'defaults to 1024x1024 for nil size' do
      payload = described_class.render_image_payload('test', model: 'flux', size: nil)
      expect(payload[:width]).to eq(1024)
      expect(payload[:height]).to eq(1024)
    end
  end

  describe '.parse_image_response' do
    it 'returns Image with base64 data for image response' do
      body = 'fake image binary data'
      headers = { 'content-type' => 'image/jpeg' }
      response = instance_double(Faraday::Response, body: body, headers: headers)

      image = described_class.parse_image_response(response, model: 'flux')

      expect(image).to be_a(RubyLLM::Image)
      expect(image.data).to eq(Base64.strict_encode64(body))
      expect(image.mime_type).to eq('image/jpeg')
      expect(image.model_id).to eq('flux')
    end

    it 'detects video from content-type' do
      body = 'fake video binary data'
      headers = { 'content-type' => 'video/mp4' }
      response = instance_double(Faraday::Response, body: body, headers: headers)

      image = described_class.parse_image_response(response, model: 'flux')

      expect(image.mime_type).to eq('video/mp4')
    end

    it 'detects video from model name' do
      body = 'fake video binary data'
      headers = { 'content-type' => 'application/octet-stream' }
      response = instance_double(Faraday::Response, body: body, headers: headers)

      image = described_class.parse_image_response(response, model: 'veo')

      expect(image.mime_type).to eq('video/mp4')
    end

    it 'handles PNG images' do
      body = 'PNG data'
      headers = { 'content-type' => 'image/png' }
      response = instance_double(Faraday::Response, body: body, headers: headers)

      image = described_class.parse_image_response(response, model: 'flux')

      expect(image.mime_type).to eq('image/png')
    end
  end

  describe '.video_model?' do
    it 'returns true for veo' do
      expect(described_class.video_model?('veo')).to be true
    end

    it 'returns true for seedance' do
      expect(described_class.video_model?('seedance')).to be true
    end

    it 'returns true for seedance-pro' do
      expect(described_class.video_model?('seedance-pro')).to be true
    end

    it 'returns true for grok-video' do
      expect(described_class.video_model?('grok-video')).to be true
    end

    it 'returns true for ltx-2' do
      expect(described_class.video_model?('ltx-2')).to be true
    end

    it 'returns false for image models' do
      expect(described_class.video_model?('flux')).to be false
      expect(described_class.video_model?('zimage')).to be false
    end

    it 'handles case insensitivity' do
      expect(described_class.video_model?('VEO')).to be true
      expect(described_class.video_model?('Seedance')).to be true
    end
  end

  describe '.build_image_params' do
    it 'includes basic params' do
      params = described_class.build_image_params(model: 'flux', width: 512, height: 512)
      expect(params[:model]).to eq('flux')
      expect(params[:width]).to eq(512)
      expect(params[:height]).to eq(512)
    end

    it 'includes seed' do
      params = described_class.build_image_params(model: 'flux', seed: 12_345)
      expect(params[:seed]).to eq(12_345)
    end

    it 'includes boolean params with explicit false' do
      params = described_class.build_image_params(model: 'flux', safe: false, enhance: true)
      expect(params[:safe]).to eq(false)
      expect(params[:enhance]).to eq(true)
    end

    it 'includes negative_prompt' do
      params = described_class.build_image_params(model: 'flux', negative_prompt: 'blurry, low quality')
      expect(params[:negative_prompt]).to eq('blurry, low quality')
    end

    it 'includes video params for video models' do
      params = described_class.build_image_params(
        model: 'veo',
        duration: 6,
        aspect_ratio: '16:9',
        audio: true
      )
      expect(params[:duration]).to eq(6)
      expect(params[:aspectRatio]).to eq('16:9')
      expect(params[:audio]).to eq(true)
    end

    it 'does not include video params for image models' do
      params = described_class.build_image_params(
        model: 'flux',
        duration: 6,
        aspect_ratio: '16:9'
      )
      expect(params).not_to have_key(:duration)
      expect(params).not_to have_key(:aspectRatio)
    end
  end

  describe '.parse_size' do
    it 'parses standard size format' do
      width, height = described_class.parse_size('1024x768')
      expect(width).to eq(1024)
      expect(height).to eq(768)
    end

    it 'returns default for nil' do
      width, height = described_class.parse_size(nil)
      expect(width).to eq(1024)
      expect(height).to eq(1024)
    end

    it 'returns default for invalid format' do
      width, height = described_class.parse_size('invalid')
      expect(width).to eq(1024)
      expect(height).to eq(1024)
    end
  end
end
