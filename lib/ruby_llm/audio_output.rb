# frozen_string_literal: true

module RubyLLM
  class AudioOutput
    attr_reader :data, :mime_type, :model_id, :duration

    def initialize(data: nil, mime_type: nil, model_id: nil, duration: nil)
      @data = data
      @mime_type = mime_type
      @model_id = model_id
      @duration = duration
    end

    def base64?
      !@data.nil?
    end

    def to_blob
      return unless base64?

      Base64.decode64(@data)
    end

    def save(path)
      File.binwrite(File.expand_path(path), to_blob)
      path
    end

    def self.speak(input, model: nil, voice: nil, provider: nil, assume_model_exists: false, context: nil, **options) # rubocop:disable Metrics/ParameterLists
      config = context&.config || RubyLLM.config
      model ||= config.default_audio_model
      model, provider_instance = Models.resolve(model, provider: provider, assume_exists: assume_model_exists,
                                                       config: config)
      model_id = model.id

      provider_instance.speak(input, model: model_id, voice: voice, **options)
    end
  end
end
