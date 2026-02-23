# RubyLLM - Codebase Summary

**Version:** 1.11.0  
**Total LOC:** ~22,700 (13,600 in lib/, 9,100 in spec/)  
**Ruby Version:** >= 3.1.3  
**Last Updated:** Feb 2026

## Repository Structure

```
ruby_llm/
├── lib/
│   ├── ruby_llm.rb                    # 114 lines - Entry point, provider registry
│   └── ruby_llm/
│       ├── chat.rb                    # 227 lines - Conversation management
│       ├── provider.rb                # 257 lines - Base provider class
│       ├── models.rb                  # 505 lines - Model registry
│       ├── tool.rb                    # 210 lines - Function calling system
│       ├── streaming.rb               # 176 lines - SSE stream handling
│       ├── configuration.rb           # 83 lines - Configuration DSL
│       ├── attachment.rb              # 220 lines - File attachment handling
│       ├── content.rb                 # 74 lines - Multimodal content
│       ├── message.rb                 # 106 lines - Message structure
│       ├── version.rb                 # 5 lines - Version constant
│       ├── active_record/             # Rails integration
│       │   ├── acts_as.rb             # acts_as_* macros
│       │   ├── chat_methods.rb        # Chat AR extensions
│       │   ├── message_methods.rb     # Message AR extensions
│       │   └── model_methods.rb       # Model registry AR
│       └── providers/                 # 13 provider implementations
│           ├── openai/
│           │   ├── chat.rb            # Chat completions
│           │   ├── embeddings.rb      # Text embeddings
│           │   ├── images.rb          # DALL-E generation
│           │   ├── transcription.rb   # Whisper audio
│           │   ├── moderation.rb      # Content moderation
│           │   ├── tools.rb           # Function calling
│           │   └── streaming.rb       # SSE streaming
│           ├── anthropic/
│           ├── gemini/
│           ├── azure/
│           ├── bedrock/
│           ├── vertexai/
│           ├── deepseek/
│           ├── mistral/
│           ├── ollama/
│           ├── gpustack/
│           ├── openrouter/
│           ├── perplexity/
│           └── xai/
├── spec/                              # RSpec test suite
│   ├── ruby_llm_spec.rb
│   ├── chat_spec.rb
│   ├── models_spec.rb
│   ├── providers/                     # Provider-specific tests
│   └── fixtures/
│       └── vcr_cassettes/             # Recorded HTTP interactions
├── docs/                              # Jekyll documentation site
│   ├── _config.yml
│   ├── index.md
│   ├── quickstart.md
│   └── ...
├── config/
│   └── models.yml                     # 800+ model definitions
├── .github/
│   └── workflows/
│       └── ci.yml                     # CI pipeline
├── Gemfile
├── ruby_llm.gemspec
├── Rakefile
├── CONTRIBUTING.md
├── CHANGELOG.md
└── README.md
```

## Core Components

### 1. Main Entry Point (`lib/ruby_llm.rb`)

**Responsibilities:**
- Public API methods: `.chat()`, `.paint()`, `.embed()`, `.transcribe()`, `.moderate()`
- Provider registration và resolution
- Configuration initialization
- Module namespace definition

**Key Methods:**
```ruby
module RubyLLM
  def self.chat(model: nil, provider: nil, **options)
    # Create Chat instance with model/provider resolution
  end
  
  def self.paint(prompt:, model: nil, **options)
    # Image generation via resolved provider
  end
  
  def self.embed(text: nil, texts: nil, model: nil, **options)
    # Text embeddings via resolved provider
  end
  
  def self.transcribe(audio:, model: nil, **options)
    # Audio transcription via resolved provider
  end
  
  def self.moderate(text:, model: nil, **options)
    # Content moderation via resolved provider
  end
  
  def self.configure
    yield Configuration.instance
  end
  
  def self.models
    Models.instance
  end
end
```

**Dependencies:**
- `zeitwerk` for autoloading
- `faraday` for HTTP
- `marcel` for MIME detection

### 2. Chat Conversation (`lib/ruby_llm/chat.rb`)

**Responsibilities:**
- Manage conversation history (messages)
- Build requests với system prompts, tools, attachments
- Coordinate với provider implementations
- Handle sync và async requests
- Support streaming responses

**Key Attributes:**
```ruby
class Chat
  attr_reader :model, :provider, :messages, :tools, :system_prompt
  attr_accessor :temperature, :max_tokens, :top_p, :stream
end
```

**Key Methods:**
```ruby
# Add message and get response
def ask(content, **options)
  add_message(role: 'user', content: content)
  response = provider.chat(messages: messages, **merged_options)
  add_message(role: 'assistant', content: response.text)
  response
end

# Streaming variant
def stream(content, **options, &block)
  add_message(role: 'user', content: content)
  provider.stream(messages: messages, **merged_options, &block)
end

# Tool registration
def with_tool(tool_class)
  @tools << tool_class
  self
end

# Attachment handling
def attach(files: [], images: [], videos: [], documents: [])
  # Convert files to Attachment objects
  # Store for next request
end
```

**Flow:**
1. User calls `chat.ask("question")`
2. Message added to history
3. Chat builds request payload (messages + tools + attachments)
4. Delegates to provider's `chat()` method
5. Provider transforms to API-specific format
6. HTTP request sent via Faraday
7. Response parsed and returned
8. Assistant message added to history

### 3. Provider Base (`lib/ruby_llm/provider.rb`)

**Responsibilities:**
- Define interface for all providers
- Implement streaming support via `Streaming` module
- Connection management với Faraday
- Error handling và retries

**Interface (abstract methods):**
```ruby
class Provider
  # Must be implemented by subclasses
  def chat(messages:, **options)
    raise NotImplementedError
  end
  
  def embed(text:, **options)
    raise NotImplementedError
  end
  
  def paint(prompt:, **options)
    raise NotImplementedError
  end
  
  def transcribe(audio:, **options)
    raise NotImplementedError
  end
  
  def moderate(text:, **options)
    raise NotImplementedError
  end
end
```

**Shared Utilities:**
```ruby
# HTTP connection with middleware
def connection
  @connection ||= Faraday.new(api_base) do |conn|
    conn.request :authorization, 'Bearer', api_key
    conn.request :json
    conn.response :json
    conn.adapter Faraday.default_adapter
  end
end

# Streaming support
include Streaming

def stream(messages:, **options, &block)
  connection.post(endpoint) do |req|
    req.body = build_request(messages, stream: true, **options)
    req.options.on_data = ->(chunk) { handle_stream_chunk(chunk, &block) }
  end
end
```

**Error Handling:**
```ruby
def handle_response(response)
  case response.status
  when 200..299
    parse_success(response)
  when 401
    raise AuthenticationError, "Invalid API key"
  when 429
    raise RateLimitError, "Rate limit exceeded"
  when 404
    raise ModelNotFoundError, "Model not found"
  else
    raise ProviderError, "Provider error: #{response.body}"
  end
end
```

### 4. Model Registry (`lib/ruby_llm/models.rb`)

**Responsibilities:**
- Maintain database of 800+ models
- Resolve model names to providers
- Capability detection (vision, tools, embeddings, etc.)
- Pricing và context window metadata

**Data Structure:**
```ruby
# config/models.yml
openai:
  gpt-4o:
    provider: openai
    capabilities: [chat, vision, tools, streaming, json_mode]
    context_window: 128000
    max_output: 16384
    input_price: 2.50
    output_price: 10.00
  
anthropic:
  claude-3-5-sonnet-20241022:
    provider: anthropic
    capabilities: [chat, vision, tools, streaming]
    context_window: 200000
    max_output: 8192
    input_price: 3.00
    output_price: 15.00
```

**Key Methods:**
```ruby
class Models
  def find(model_name)
    # Resolve model_name to Model instance
    # Handle provider prefixes (e.g., "openai/gpt-4o")
  end
  
  def list(provider: nil)
    # Return all models, optionally filtered by provider
  end
  
  def with_capability(capability)
    # Filter models by capability (:vision, :tools, etc.)
  end
  
  def default_for_provider(provider)
    # Get default model for a provider
  end
end

class Model
  attr_reader :name, :provider, :capabilities, :context_window,
              :max_output, :input_price, :output_price
  
  def supports?(capability)
    capabilities.include?(capability)
  end
end
```

**Resolution Logic:**
```ruby
# Priority order:
# 1. Explicit provider + model name
# 2. Model name with provider prefix (e.g., "anthropic/claude-3-5-sonnet")
# 3. Exact model name match in registry
# 4. Fuzzy match (model name contains substring)
# 5. Default model for configured provider
```

### 5. Tool System (`lib/ruby_llm/tool.rb`)

**Responsibilities:**
- Define tool/function calling interface
- Generate JSON schema for tool definitions
- Execute tool calls và return results
- Handle tool call loops (multi-turn)

**Base Class:**
```ruby
class Tool
  class << self
    # DSL for defining tools
    def description(text)
      @description = text
    end
    
    def param(name, type:, description: nil, enum: nil, required: true)
      @parameters ||= []
      @parameters << {
        name: name,
        type: type,
        description: description,
        enum: enum,
        required: required
      }
    end
    
    # Generate JSON schema for OpenAI/Anthropic
    def to_schema
      {
        type: "function",
        function: {
          name: name.underscore,
          description: @description,
          parameters: {
            type: "object",
            properties: parameters_hash,
            required: required_params
          }
        }
      }
    end
  end
  
  # Must be implemented by subclasses
  def execute(**args)
    raise NotImplementedError
  end
end
```

**Example Tool:**
```ruby
class WeatherTool < RubyLLM::Tool
  description "Get current weather for a location"
  
  param :location, type: 'string', description: 'City name'
  param :units, type: 'string', enum: ['celsius', 'fahrenheit'], required: false
  
  def execute(location:, units: 'celsius')
    # Call weather API
    { temperature: 72, condition: "Sunny", units: units }
  end
end
```

**Tool Execution Flow:**
```ruby
# 1. User attaches tool to chat
chat.with_tool(WeatherTool)

# 2. Chat includes tool schema in request
request = {
  model: "gpt-4o",
  messages: [...],
  tools: [WeatherTool.to_schema]
}

# 3. Provider returns tool call
response = {
  tool_calls: [
    { id: "call_123", name: "weather_tool", arguments: { location: "NYC" } }
  ]
}

# 4. Chat executes tool
tool_instance = WeatherTool.new
result = tool_instance.execute(location: "NYC")

# 5. Chat adds tool result to messages
messages << {
  role: "tool",
  tool_call_id: "call_123",
  content: result.to_json
}

# 6. Chat sends follow-up request with tool result
# Provider generates final response using tool output
```

### 6. Streaming (`lib/ruby_llm/streaming.rb`)

**Responsibilities:**
- Parse Server-Sent Events (SSE)
- Handle chunked responses
- Yield incremental updates to blocks
- Reconstruct complete messages from chunks

**Implementation:**
```ruby
module Streaming
  class StreamChunk
    attr_reader :text, :tool_calls, :finish_reason
    
    def initialize(text: nil, tool_calls: nil, finish_reason: nil)
      @text = text
      @tool_calls = tool_calls
      @finish_reason = finish_reason
    end
  end
  
  def stream(messages:, **options, &block)
    accumulated_text = ""
    accumulated_tools = []
    
    connection.post(endpoint) do |req|
      req.body = build_request(messages, stream: true, **options)
      
      req.options.on_data = lambda do |chunk, _size|
        lines = chunk.split("\n").select { |l| l.start_with?("data: ") }
        
        lines.each do |line|
          data = line.sub("data: ", "")
          next if data == "[DONE]"
          
          json = JSON.parse(data)
          delta = extract_delta(json)
          
          if delta[:text]
            accumulated_text += delta[:text]
            yield StreamChunk.new(text: delta[:text])
          end
          
          if delta[:tool_calls]
            accumulated_tools += delta[:tool_calls]
            yield StreamChunk.new(tool_calls: delta[:tool_calls])
          end
          
          if delta[:finish_reason]
            yield StreamChunk.new(
              text: accumulated_text,
              tool_calls: accumulated_tools,
              finish_reason: delta[:finish_reason]
            )
          end
        end
      end
    end
  end
  
  private
  
  def extract_delta(json)
    # Provider-specific parsing logic
    # OpenAI: json["choices"][0]["delta"]
    # Anthropic: json["delta"]
  end
end
```

### 7. Attachments (`lib/ruby_llm/attachment.rb`)

**Responsibilities:**
- Handle files, images, videos, documents
- Detect MIME types
- Encode to base64 hoặc upload to URLs
- Support local files và remote URLs

**Implementation:**
```ruby
class Attachment
  attr_reader :path, :url, :mime_type, :content
  
  def initialize(source)
    if source.start_with?('http')
      @url = source
      @mime_type = detect_mime_from_url(source)
    else
      @path = source
      @mime_type = Marcel::MimeType.for(Pathname.new(source))
      @content = File.read(source)
    end
  end
  
  def image?
    mime_type.start_with?('image/')
  end
  
  def video?
    mime_type.start_with?('video/')
  end
  
  def document?
    ['application/pdf', 'text/csv', 'text/plain'].include?(mime_type)
  end
  
  def to_base64
    Base64.strict_encode64(content)
  end
  
  def to_data_uri
    "data:#{mime_type};base64,#{to_base64}"
  end
  
  # Provider-specific formatting
  def to_openai_format
    {
      type: image? ? "image_url" : "text",
      image_url: { url: url || to_data_uri }
    }
  end
  
  def to_anthropic_format
    {
      type: "image",
      source: {
        type: "base64",
        media_type: mime_type,
        data: to_base64
      }
    }
  end
  
  def to_gemini_format
    {
      inline_data: {
        mime_type: mime_type,
        data: to_base64
      }
    }
  end
end
```

### 8. Content & Messages (`lib/ruby_llm/content.rb`, `lib/ruby_llm/message.rb`)

**Content:**
```ruby
class Content
  attr_reader :type, :text, :image_url, :tool_call_id
  
  def initialize(type:, **attributes)
    @type = type # "text", "image_url", "tool_result"
    @text = attributes[:text]
    @image_url = attributes[:image_url]
    @tool_call_id = attributes[:tool_call_id]
  end
  
  def text?
    type == "text"
  end
  
  def image?
    type == "image_url"
  end
end
```

**Message:**
```ruby
class Message
  attr_reader :role, :content, :tool_calls, :name
  
  def initialize(role:, content: nil, tool_calls: nil, name: nil)
    @role = role # "user", "assistant", "system", "tool"
    @content = normalize_content(content)
    @tool_calls = tool_calls
    @name = name
  end
  
  def to_openai
    {
      role: role,
      content: content_to_openai,
      tool_calls: tool_calls
    }.compact
  end
  
  def to_anthropic
    {
      role: role,
      content: content_to_anthropic
    }
  end
  
  private
  
  def normalize_content(content)
    case content
    when String
      [Content.new(type: "text", text: content)]
    when Array
      content.map { |c| Content.new(**c) }
    when Content
      [content]
    end
  end
end
```

### 9. Configuration (`lib/ruby_llm/configuration.rb`)

**Responsibilities:**
- Store API keys và credentials
- Provider-specific settings (endpoints, versions)
- Default values (timeouts, retries)
- Singleton pattern

**Implementation:**
```ruby
class Configuration
  include Singleton
  
  # API Keys
  attr_accessor :openai_api_key, :anthropic_api_key, :gemini_api_key,
                :deepseek_api_key, :mistral_api_key, :openrouter_api_key,
                :perplexity_api_key, :xai_api_key
  
  # Azure OpenAI
  attr_accessor :azure_api_base, :azure_api_version, :azure_deployment_name,
                :azure_api_key, :azure_ad_token
  
  # AWS Bedrock
  attr_accessor :bedrock_region, :bedrock_access_key_id,
                :bedrock_secret_access_key, :bedrock_session_token
  
  # Google Vertex AI
  attr_accessor :vertex_project_id, :vertex_location, :vertex_credentials
  
  # Self-hosted
  attr_accessor :ollama_api_base, :gpustack_api_base, :gpustack_api_key
  
  # Defaults
  attr_accessor :default_provider, :default_model, :timeout, :open_timeout,
                :max_retries, :retry_interval
  
  # Middleware
  attr_accessor :faraday_middleware
  
  def initialize
    @timeout = 120
    @open_timeout = 10
    @max_retries = 3
    @retry_interval = 2
    @ollama_api_base = "http://localhost:11434"
  end
end
```

### 10. Rails Integration (`lib/ruby_llm/active_record/`)

**acts_as_chat:**
```ruby
module RubyLLM
  module ActiveRecord
    module ActsAs
      def acts_as_chat
        include ChatMethods
        
        has_many :messages, class_name: "ChatMessage", dependent: :destroy
        belongs_to :model, class_name: "LlmModel", optional: true
        
        after_initialize :setup_chat_instance
      end
    end
  end
end
```

**ChatMethods:**
```ruby
module ChatMethods
  def ask(content, **options)
    @chat_instance ||= RubyLLM.chat(model: model_name, **options)
    response = @chat_instance.ask(content, **options)
    
    # Persist user message
    messages.create!(
      role: 'user',
      content: content
    )
    
    # Persist assistant message
    messages.create!(
      role: 'assistant',
      content: response.text,
      tool_calls: response.tool_calls
    )
    
    response
  end
  
  def with_tool(tool_class)
    @chat_instance.with_tool(tool_class)
    self
  end
  
  def reload_messages
    @chat_instance = nil
    @chat_instance = RubyLLM.chat(model: model_name)
    messages.order(:created_at).each do |msg|
      @chat_instance.messages << msg.to_message
    end
    self
  end
end
```

**Migration Generator:**
```ruby
# rails generate ruby_llm:install
class CreateRubyLlmTables < ActiveRecord::Migration[7.1]
  def change
    create_table :conversations do |t|
      t.string :model_name
      t.text :system_prompt
      t.timestamps
    end
    
    create_table :chat_messages do |t|
      t.references :conversation, foreign_key: true
      t.string :role, null: false
      t.text :content
      t.json :tool_calls
      t.timestamps
    end
    
    create_table :llm_models do |t|
      t.string :name, null: false
      t.string :provider, null: false
      t.json :capabilities
      t.timestamps
    end
  end
end
```

## Provider Implementations

### OpenAI Provider (`lib/ruby_llm/providers/openai/`)

**Structure:**
```
openai/
├── chat.rb           # Chat completions API
├── embeddings.rb     # Embeddings API
├── images.rb         # DALL-E image generation
├── transcription.rb  # Whisper audio transcription
├── moderation.rb     # Content moderation API
├── tools.rb          # Function calling support
└── streaming.rb      # SSE streaming
```

**Chat Implementation:**
```ruby
module RubyLLM
  module Providers
    class OpenAI < Provider
      def chat(messages:, **options)
        response = connection.post('/chat/completions') do |req|
          req.body = {
            model: model_name,
            messages: format_messages(messages),
            tools: format_tools(options[:tools]),
            temperature: options[:temperature],
            max_tokens: options[:max_tokens],
            stream: false
          }.compact
        end
        
        parse_chat_response(response.body)
      end
      
      private
      
      def format_messages(messages)
        messages.map do |msg|
          {
            role: msg.role,
            content: format_content(msg.content),
            tool_calls: msg.tool_calls
          }.compact
        end
      end
      
      def format_content(content)
        return content if content.is_a?(String)
        
        content.map do |part|
          case part.type
          when "text"
            { type: "text", text: part.text }
          when "image_url"
            { type: "image_url", image_url: { url: part.image_url } }
          end
        end
      end
      
      def format_tools(tools)
        return nil if tools.nil? || tools.empty?
        
        tools.map(&:to_schema)
      end
      
      def parse_chat_response(body)
        choice = body["choices"].first
        
        Response.new(
          text: choice.dig("message", "content"),
          tool_calls: parse_tool_calls(choice.dig("message", "tool_calls")),
          finish_reason: choice["finish_reason"],
          usage: body["usage"]
        )
      end
    end
  end
end
```

### Anthropic Provider (`lib/ruby_llm/providers/anthropic/`)

**Key Differences:**
- Messages API requires system prompt as separate parameter
- Content must be array format (không support string shorthand)
- Tool results sent as user messages với tool_result type

```ruby
def chat(messages:, **options)
  # Extract system prompt from messages
  system_message = messages.find { |m| m.role == "system" }
  user_messages = messages.reject { |m| m.role == "system" }
  
  response = connection.post('/v1/messages') do |req|
    req.headers['anthropic-version'] = '2023-06-01'
    req.body = {
      model: model_name,
      system: system_message&.content,
      messages: format_messages(user_messages),
      tools: format_tools(options[:tools]),
      max_tokens: options[:max_tokens] || 4096, # Required!
      temperature: options[:temperature]
    }.compact
  end
  
  parse_response(response.body)
end

def format_messages(messages)
  messages.map do |msg|
    {
      role: msg.role == "tool" ? "user" : msg.role,
      content: format_content(msg)
    }
  end
end

def format_content(message)
  if message.role == "tool"
    [{
      type: "tool_result",
      tool_use_id: message.tool_call_id,
      content: message.content
    }]
  else
    message.content.map do |part|
      case part.type
      when "text"
        { type: "text", text: part.text }
      when "image_url"
        {
          type: "image",
          source: {
            type: "base64",
            media_type: detect_mime_type(part.image_url),
            data: extract_base64(part.image_url)
          }
        }
      end
    end
  end
end
```

### Gemini Provider (`lib/ruby_llm/providers/gemini/`)

**Key Differences:**
- Uses `generateContent` endpoint
- Parts-based content structure
- Inline data cho attachments

```ruby
def chat(messages:, **options)
  response = connection.post("/v1/models/#{model_name}:generateContent") do |req|
    req.params = { key: api_key }
    req.body = {
      contents: format_messages(messages),
      generationConfig: {
        temperature: options[:temperature],
        maxOutputTokens: options[:max_tokens]
      }.compact,
      tools: format_tools(options[:tools])
    }.compact
  end
  
  parse_response(response.body)
end

def format_messages(messages)
  messages.map do |msg|
    {
      role: role_mapping(msg.role),
      parts: format_parts(msg.content)
    }
  end
end

def format_parts(content)
  content.map do |part|
    case part.type
    when "text"
      { text: part.text }
    when "image_url"
      {
        inline_data: {
          mime_type: detect_mime_type(part.image_url),
          data: extract_base64(part.image_url)
        }
      }
    end
  end
end

def role_mapping(role)
  case role
  when "user" then "user"
  when "assistant" then "model"
  when "system" then "user" # Gemini không có system role
  end
end
```

### Azure OpenAI Provider

**Configuration:**
```ruby
RubyLLM.configure do |config|
  config.azure_api_base = "https://your-resource.openai.azure.com"
  config.azure_api_version = "2024-02-15-preview"
  config.azure_deployment_name = "gpt-4"
  config.azure_api_key = ENV['AZURE_OPENAI_KEY']
end
```

**Implementation:**
```ruby
def api_base
  Configuration.instance.azure_api_base
end

def api_version
  Configuration.instance.azure_api_version
end

def deployment_name
  Configuration.instance.azure_deployment_name
end

def chat(messages:, **options)
  response = connection.post("/openai/deployments/#{deployment_name}/chat/completions") do |req|
    req.params = { 'api-version' => api_version }
    req.body = build_request(messages, **options)
  end
  
  parse_chat_response(response.body)
end
```

### Self-Hosted Providers (Ollama, GPUStack)

**Ollama:**
```ruby
class Ollama < Provider
  def api_base
    Configuration.instance.ollama_api_base || "http://localhost:11434"
  end
  
  def chat(messages:, **options)
    response = connection.post('/api/chat') do |req|
      req.body = {
        model: model_name,
        messages: format_messages(messages),
        stream: false,
        options: {
          temperature: options[:temperature],
          num_predict: options[:max_tokens]
        }.compact
      }
    end
    
    parse_response(response.body)
  end
  
  def format_messages(messages)
    # Ollama uses OpenAI-compatible format
    messages.map do |msg|
      {
        role: msg.role,
        content: extract_text(msg.content)
      }
    end
  end
end
```

## Testing Infrastructure

### RSpec Configuration

**spec/spec_helper.rb:**
```ruby
require 'ruby_llm'
require 'vcr'
require 'webmock/rspec'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
  
  # Filter sensitive data
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }
  config.filter_sensitive_data('<ANTHROPIC_API_KEY>') { ENV['ANTHROPIC_API_KEY'] }
  config.filter_sensitive_data('<GEMINI_API_KEY>') { ENV['GEMINI_API_KEY'] }
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
```

### Test Structure

```
spec/
├── ruby_llm_spec.rb               # Main module tests
├── chat_spec.rb                   # Chat conversation tests
├── models_spec.rb                 # Model registry tests
├── tool_spec.rb                   # Tool system tests
├── streaming_spec.rb              # Streaming tests
├── providers/
│   ├── openai_spec.rb             # OpenAI provider
│   ├── anthropic_spec.rb          # Anthropic provider
│   ├── gemini_spec.rb             # Gemini provider
│   └── ...
├── active_record/
│   ├── acts_as_chat_spec.rb       # Rails integration
│   └── ...
└── fixtures/
    └── vcr_cassettes/             # Recorded HTTP responses
        ├── openai_chat.yml
        ├── anthropic_chat.yml
        └── ...
```

### Example Test

```ruby
RSpec.describe RubyLLM::Providers::OpenAI, :vcr do
  let(:provider) { described_class.new(model: 'gpt-4o') }
  
  describe '#chat' do
    it 'returns a response for a simple question' do
      messages = [
        RubyLLM::Message.new(role: 'user', content: 'What is 2+2?')
      ]
      
      response = provider.chat(messages: messages)
      
      expect(response.text).to include('4')
      expect(response.finish_reason).to eq('stop')
    end
    
    it 'handles tool calls' do
      tool = Class.new(RubyLLM::Tool) do
        description "Calculator"
        param :operation, type: 'string'
        param :a, type: 'number'
        param :b, type: 'number'
        
        def execute(operation:, a:, b:)
          case operation
          when 'add' then a + b
          end
        end
      end
      
      messages = [
        RubyLLM::Message.new(role: 'user', content: 'What is 5 + 3?')
      ]
      
      response = provider.chat(messages: messages, tools: [tool])
      
      expect(response.tool_calls).not_to be_empty
      expect(response.tool_calls.first.name).to eq('calculator')
    end
  end
  
  describe '#stream' do
    it 'yields chunks' do
      messages = [
        RubyLLM::Message.new(role: 'user', content: 'Count to 5')
      ]
      
      chunks = []
      provider.stream(messages: messages) do |chunk|
        chunks << chunk
      end
      
      expect(chunks).not_to be_empty
      expect(chunks.first).to be_a(RubyLLM::Streaming::StreamChunk)
    end
  end
end
```

## Dependencies

### Production Dependencies

```ruby
# ruby_llm.gemspec
spec.add_dependency 'faraday', '~> 2.0'      # HTTP client
spec.add_dependency 'zeitwerk', '~> 2.6'     # Code autoloading
spec.add_dependency 'marcel', '~> 1.0'       # MIME type detection
```

### Development Dependencies

```ruby
spec.add_development_dependency 'rspec', '~> 3.12'
spec.add_development_dependency 'vcr', '~> 6.1'
spec.add_development_dependency 'webmock', '~> 3.18'
spec.add_development_dependency 'rubocop', '~> 1.50'
spec.add_development_dependency 'rubocop-rspec', '~> 2.20'
spec.add_development_dependency 'rake', '~> 13.0'
spec.add_development_dependency 'yard', '~> 0.9'
```

## Code Metrics

### Line Count Distribution

```
Total: ~22,700 lines

lib/              ~13,600 lines (60%)
  ├── core          ~1,800 lines (chat, provider, models, tools, streaming)
  ├── providers    ~10,500 lines (13 providers × ~800 lines each)
  └── active_record ~1,300 lines (Rails integration)

spec/             ~9,100 lines (40%)
  ├── core tests    ~2,000 lines
  ├── provider tests ~6,500 lines
  └── AR tests       ~600 lines
```

### Complexity Metrics

- **Average Method Length**: 8-12 lines
- **Average Class Length**: 150-250 lines
- **Cyclomatic Complexity**: Low (well-factored methods)
- **Test Coverage**: >85% (tracked via Codecov)

### File Size Distribution

```
Small (<100 lines):      15 files (version.rb, config, utilities)
Medium (100-300 lines):  45 files (most classes)
Large (300-500 lines):   8 files (models.rb, base provider)
Very Large (>500 lines): 2 files (models.yml data)
```

## Design Patterns Summary

1. **Provider Pattern**: Base class + provider implementations
2. **Registry Pattern**: Centralized model database
3. **Builder Pattern**: Fluent chat conversation API
4. **Strategy Pattern**: Dynamic provider selection
5. **Module Mixins**: Streaming, ActiveRecord integration
6. **Singleton**: Configuration management
7. **Factory**: Message và Content object creation
8. **Template Method**: Provider base class defines workflow
9. **Adapter**: Transform between provider API formats
10. **Observer**: Streaming callbacks

## Key Architectural Decisions

1. **Minimal Dependencies**: Only 3 runtime dependencies (Faraday, Zeitwerk, Marcel)
2. **Provider Abstraction**: Unified interface despite diverse provider APIs
3. **Streaming via Fibers**: Efficient memory usage for long responses
4. **Rails Optional**: Core gem works standalone, Rails integration optional
5. **VCR Testing**: Record real API responses for reliable tests
6. **Model Registry**: YAML-based metadata for 800+ models
7. **Tool DSL**: Ruby-native function definition syntax
8. **Attachment Handling**: Support both local files và remote URLs
9. **Error Hierarchy**: Specific exceptions for different failure modes
10. **Configuration Singleton**: Thread-safe global configuration

## Future Refactoring Opportunities

1. **Provider Auto-Discovery**: Plugin system để load providers dynamically
2. **Connection Pooling**: Reuse HTTP connections across requests
3. **Response Caching**: Cache identical requests
4. **Async/Await**: Native async support với Ruby 3.x Fibers
5. **Middleware Pipeline**: Extensible request/response transformation
6. **Model Auto-Sync**: Periodically update model registry from provider APIs
7. **Streaming Backpressure**: Handle slow consumers
8. **Batch Requests**: Send multiple requests in single HTTP call
9. **Telemetry**: Built-in metrics và tracing
10. **Provider Health Checks**: Automatic failover khi provider down
