# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Pollinations::Media do
  describe '.format_content' do
    it 'returns string content directly for hashes' do
      hash_content = { key: 'value' }
      result = described_class.format_content(hash_content)
      expect(result).to eq('{"key":"value"}')
    end

    it 'returns string content directly for arrays' do
      array_content = [1, 2, 3]
      result = described_class.format_content(array_content)
      expect(result).to eq('[1,2,3]')
    end

    it 'returns value for Raw content' do
      raw_value = [{ type: 'text', text: 'hello' }]
      raw_content = RubyLLM::Content::Raw.new(raw_value)
      result = described_class.format_content(raw_content)
      expect(result).to eq(raw_value)
    end

    it 'returns plain string as-is' do
      result = described_class.format_content('Hello world')
      expect(result).to eq('Hello world')
    end
  end

  describe '.format_image' do
    it 'formats URL-based image' do
      image = instance_double(
        RubyLLM::Attachment,
        type: :image,
        url?: true,
        source: URI('https://example.com/image.png')
      )

      result = described_class.format_image(image)

      expect(result[:type]).to eq('image_url')
      expect(result[:image_url][:url]).to eq('https://example.com/image.png')
    end

    it 'formats base64-encoded image' do
      image = instance_double(
        RubyLLM::Attachment,
        type: :image,
        url?: false,
        for_llm: 'data:image/png;base64,abc123'
      )

      result = described_class.format_image(image)

      expect(result[:type]).to eq('image_url')
      expect(result[:image_url][:url]).to eq('data:image/png;base64,abc123')
    end
  end

  describe '.format_pdf' do
    it 'formats PDF with filename and data' do
      pdf = instance_double(
        RubyLLM::Attachment,
        type: :pdf,
        filename: 'document.pdf',
        for_llm: 'data:application/pdf;base64,xyz789'
      )

      result = described_class.format_pdf(pdf)

      expect(result[:type]).to eq('file')
      expect(result[:file][:filename]).to eq('document.pdf')
      expect(result[:file][:file_data]).to eq('data:application/pdf;base64,xyz789')
    end
  end

  describe '.format_audio' do
    it 'formats audio with encoded data and format' do
      audio = instance_double(
        RubyLLM::Attachment,
        type: :audio,
        encoded: 'base64audiodata',
        format: 'mp3'
      )

      result = described_class.format_audio(audio)

      expect(result[:type]).to eq('input_audio')
      expect(result[:input_audio][:data]).to eq('base64audiodata')
      expect(result[:input_audio][:format]).to eq('mp3')
    end
  end

  describe '.format_text_file' do
    it 'formats text file content' do
      text_file = instance_double(
        RubyLLM::Attachment,
        type: :text,
        for_llm: 'File contents here'
      )

      result = described_class.format_text_file(text_file)

      expect(result[:type]).to eq('text')
      expect(result[:text]).to eq('File contents here')
    end
  end

  describe '.format_text' do
    it 'formats plain text' do
      result = described_class.format_text('Hello world')

      expect(result[:type]).to eq('text')
      expect(result[:text]).to eq('Hello world')
    end
  end
end
