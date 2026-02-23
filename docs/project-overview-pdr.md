# RubyLLM - Tổng Quan Dự Án

**Phiên bản:** 1.11.0  
**Tác giả:** Carmine Paolino  
**License:** MIT  
**Repository:** https://github.com/crmne/ruby_llm  
**Trang chủ:** https://rubyllm.com

## Giới Thiệu

RubyLLM là Ruby gem cung cấp unified API để tương tác với nhiều Large Language Model providers khác nhau. Thay vì phải học cách sử dụng từng API riêng biệt của OpenAI, Anthropic, Google Gemini, và các providers khác, RubyLLM cung cấp một interface nhất quán và đơn giản.

### Vấn Đề Giải Quyết

- **Fragmentation**: Mỗi LLM provider có API khác nhau, format request/response khác nhau
- **Vendor Lock-in**: Code bị phụ thuộc vào một provider cụ thể, khó chuyển đổi
- **Complexity**: Phải xử lý streaming, tools, multimodal content theo nhiều cách khác nhau
- **Rails Integration**: Thiếu integration sẵn có với ActiveRecord để persist conversations

### Giải Pháp

RubyLLM cung cấp:

1. **Unified Interface**: Một API cho tất cả providers
2. **Provider Abstraction**: Dễ dàng switch providers mà không đổi code
3. **Rich Features**: Hỗ trợ đầy đủ chat, vision, audio, documents, embeddings, image generation
4. **Rails Integration**: `acts_as_chat` pattern để persist conversations vào database
5. **Model Registry**: 800+ models với capability detection tự động

## Core Features

### 1. Chat Conversations

```ruby
chat = RubyLLM.chat(model: "gpt-4o")
response = chat.ask("Explain quantum computing")
puts response.text
```

**Tính năng:**
- Sync và async requests
- Conversation history tự động
- System prompts
- Structured output với JSON schema
- Tool/function calling

### 2. Multimodal Support

**Vision (Images & Videos):**
```ruby
chat.ask("What's in this image?", images: ["path/to/image.jpg"])
chat.ask("Analyze this video", videos: ["path/to/video.mp4"])
```

**Documents (PDFs, CSVs, etc.):**
```ruby
chat.ask("Summarize this document", documents: ["report.pdf"])
```

**Audio Transcription:**
```ruby
transcript = RubyLLM.transcribe("audio.mp3")
```

### 3. Image Generation

```ruby
image_url = RubyLLM.paint(
  prompt: "A sunset over mountains",
  model: "dall-e-3"
)
```

### 4. Embeddings

```ruby
embedding = RubyLLM.embed(
  text: "Sample text for embedding",
  model: "text-embedding-3-small"
)
```

### 5. Content Moderation

```ruby
result = RubyLLM.moderate("User input text")
puts result.flagged # true/false
```

### 6. Streaming Responses

```ruby
chat.stream("Tell me a story") do |chunk|
  print chunk.text
end
```

### 7. Tool/Function Calling

```ruby
class WeatherTool < RubyLLM::Tool
  description "Get current weather"
  param :location, type: 'string'
  
  def execute(location:)
    { temperature: 72, condition: "Sunny" }
  end
end

chat.with_tool(WeatherTool).ask("What's the weather in NYC?")
```

### 8. Rails Integration

```ruby
# Model setup
class Conversation < ApplicationRecord
  acts_as_chat
end

class ChatMessage < ApplicationRecord
  acts_as_message
end

# Usage
conversation = Conversation.create(model: "gpt-4o")
conversation.ask("Hello, AI!")
conversation.messages # Access all messages
```

## Supported Providers (13)

| Provider | Status | Highlights |
|----------|--------|------------|
| **OpenAI** | ✓ Full | GPT-4o, GPT-4, GPT-3.5, DALL-E, Whisper, Moderation |
| **Anthropic** | ✓ Full | Claude 3.5 Sonnet, Claude 3 Opus/Haiku |
| **Google Gemini** | ✓ Full | Gemini Pro, Gemini Flash, Vision, Audio |
| **Azure OpenAI** | ✓ Full | Azure-hosted OpenAI models |
| **AWS Bedrock** | ✓ Chat | Claude, Llama, Mistral trên AWS |
| **Google VertexAI** | ✓ Full | Gemini trên Google Cloud |
| **DeepSeek** | ✓ Full | DeepSeek-V3, R1 models |
| **Mistral** | ✓ Full | Mistral Large, Codestral |
| **Ollama** | ✓ Full | Local models (Llama, Phi, etc.) |
| **GPUStack** | ✓ Full | Self-hosted GPU cluster |
| **OpenRouter** | ✓ Full | Aggregator cho 100+ models |
| **Perplexity** | ✓ Full | Search-augmented models |
| **xAI** | ✓ Full | Grok models |

## Architecture Overview

### High-Level Design

```
┌─────────────────────────────────────────────────┐
│           Application Layer                     │
│  (Rails apps, scripts, gems using RubyLLM)     │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│         RubyLLM Public API                      │
│  .chat() .paint() .embed() .transcribe()       │
│  .moderate() .models()                          │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│         Core Components                         │
│  ┌──────────┐ ┌─────────┐ ┌─────────────┐     │
│  │  Chat    │ │  Tool   │ │  Attachment │     │
│  └──────────┘ └─────────┘ └─────────────┘     │
│  ┌──────────┐ ┌─────────┐ ┌─────────────┐     │
│  │ Message  │ │ Content │ │  Streaming  │     │
│  └──────────┘ └─────────┘ └─────────────┘     │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│         Provider Layer                          │
│  Base Provider + 13 Provider Implementations    │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│         HTTP Layer (Faraday)                    │
│  Connection pooling, retries, timeouts          │
└───────────────────┬─────────────────────────────┘
                    │
┌───────────────────▼─────────────────────────────┐
│      External LLM Provider APIs                 │
│  OpenAI, Anthropic, Google, AWS, etc.          │
└─────────────────────────────────────────────────┘
```

### Key Design Patterns

1. **Provider Pattern**: `RubyLLM::Provider` base class, mỗi provider extends và implement methods cụ thể
2. **Registry Pattern**: `RubyLLM::Models` quản lý 800+ models với capability metadata
3. **Builder Pattern**: `RubyLLM::Chat` xây dựng conversations với fluent interface
4. **Strategy Pattern**: Provider selection dựa trên model name hoặc explicit configuration
5. **ActiveRecord Integration**: `acts_as_*` macros để extend AR models

## Technical Specifications

### Requirements

- **Ruby**: >= 3.1.3
- **Rails** (optional): >= 7.1 (nếu dùng `acts_as_chat`)
- **Dependencies**: Minimal
  - `faraday` (~> 2.0) - HTTP client
  - `zeitwerk` (~> 2.6) - Code loading
  - `marcel` (~> 1.0) - MIME type detection

### Performance Characteristics

- **Lightweight**: ~13,600 LOC, minimal dependencies
- **Memory**: Efficient streaming với fiber-based concurrency
- **Concurrency**: Thread-safe, hỗ trợ async operations
- **Connection Pooling**: Faraday middleware tái sử dụng connections

### Testing & Quality

- **Test Framework**: RSpec
- **Coverage**: High (tracked via Codecov)
- **VCR Cassettes**: Record/replay HTTP interactions
- **CI Matrix**: Ruby 3.1-4.0 + JRuby × Rails 7.1-8.1
- **Linting**: Rubocop với strict config

## Installation & Configuration

### Basic Installation

```ruby
# Gemfile
gem 'ruby_llm'

# Bundle install
bundle install
```

### Configuration

```ruby
# config/initializers/ruby_llm.rb (Rails)
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  
  # Optional settings
  config.default_provider = :openai
  config.default_model = "gpt-4o-mini"
  config.timeout = 120
  config.max_retries = 3
end
```

### Rails Installation

```bash
# Full setup với migrations và initializer
rails generate ruby_llm:install

# Chỉ tạo chat UI với Turbo streaming
rails generate ruby_llm:chat_ui
```

## Usage Examples

### Basic Chat

```ruby
# Simple question-answer
chat = RubyLLM.chat(model: "gpt-4o")
response = chat.ask("What is Ruby?")
puts response.text

# Conversation with history
chat.ask("Tell me about Ruby")
chat.ask("What about Python?") # Context preserved
chat.ask("Compare them") # References both
```

### System Prompts

```ruby
chat = RubyLLM.chat(
  model: "claude-3-5-sonnet-20241022",
  system: "You are a helpful coding assistant specializing in Ruby."
)

chat.ask("How do I create a class in Ruby?")
```

### Structured Output

```ruby
schema = {
  type: "object",
  properties: {
    name: { type: "string" },
    age: { type: "integer" },
    hobbies: { type: "array", items: { type: "string" } }
  },
  required: ["name", "age"]
}

chat = RubyLLM.chat(model: "gpt-4o")
response = chat.ask(
  "Extract person info: John is 30 and likes hiking and reading",
  response_format: { type: "json_schema", json_schema: schema }
)

data = JSON.parse(response.text)
# => { "name" => "John", "age" => 30, "hobbies" => ["hiking", "reading"] }
```

### Vision with Images

```ruby
chat = RubyLLM.chat(model: "gpt-4o")

# Local file
response = chat.ask(
  "Describe this image",
  images: ["screenshot.png"]
)

# Remote URL
response = chat.ask(
  "What's in this photo?",
  images: ["https://example.com/photo.jpg"]
)

# Multiple images
response = chat.ask(
  "Compare these images",
  images: ["image1.jpg", "image2.jpg"]
)
```

### Document Analysis

```ruby
chat = RubyLLM.chat(model: "gemini-pro")

# PDF analysis
response = chat.ask(
  "Summarize the key points",
  documents: ["report.pdf"]
)

# CSV data analysis
response = chat.ask(
  "What trends do you see?",
  documents: ["data.csv"]
)

# Multiple documents
response = chat.ask(
  "Compare these reports",
  documents: ["q1_report.pdf", "q2_report.pdf"]
)
```

### Streaming Responses

```ruby
chat = RubyLLM.chat(model: "gpt-4o")

# Print chunks as they arrive
chat.stream("Write a poem about Ruby") do |chunk|
  print chunk.text
  STDOUT.flush
end

# Process structured chunks
chat.stream("Explain recursion") do |chunk|
  if chunk.tool_calls
    # Handle tool calls
  elsif chunk.text
    # Handle text
  end
end
```

### Tools/Function Calling

```ruby
# Define tool
class CalculatorTool < RubyLLM::Tool
  description "Perform mathematical calculations"
  
  param :operation, type: 'string', enum: ['add', 'subtract', 'multiply', 'divide']
  param :a, type: 'number', description: 'First operand'
  param :b, type: 'number', description: 'Second operand'
  
  def execute(operation:, a:, b:)
    case operation
    when 'add' then a + b
    when 'subtract' then a - b
    when 'multiply' then a * b
    when 'divide' then a / b.to_f
    end
  end
end

# Use tool
chat = RubyLLM.chat(model: "gpt-4o")
chat.with_tool(CalculatorTool)

response = chat.ask("What is 15 multiplied by 7?")
# Tool is automatically invoked, result returned in response
```

### Rails Persistence

```ruby
# Create conversation
conversation = Conversation.create(
  model: "gpt-4o",
  system_prompt: "You are a helpful assistant"
)

# Add messages
conversation.ask("Hello!")
conversation.ask("Tell me a joke")

# Access history
conversation.messages.each do |msg|
  puts "#{msg.role}: #{msg.content}"
end

# Continue conversation
conversation.ask("Another joke?") # Full context preserved

# Tools with persistence
conversation.with_tool(WeatherTool)
conversation.ask("What's the weather?")

# Tool calls are also persisted
conversation.messages.last.tool_calls.each do |tc|
  puts "Tool: #{tc.name}, Args: #{tc.arguments}"
end
```

### Embeddings

```ruby
# Single text
embedding = RubyLLM.embed(
  text: "Ruby is a dynamic programming language",
  model: "text-embedding-3-small"
)

embedding.vector # => [0.123, -0.456, ...]
embedding.dimensions # => 1536

# Batch embeddings
embeddings = RubyLLM.embed(
  texts: ["Text 1", "Text 2", "Text 3"],
  model: "text-embedding-3-small"
)

embeddings.each do |emb|
  puts emb.vector.length
end
```

### Image Generation

```ruby
# Basic generation
image_url = RubyLLM.paint(
  prompt: "A futuristic city at sunset",
  model: "dall-e-3"
)

# With options
image_url = RubyLLM.paint(
  prompt: "A cat wearing a space helmet",
  model: "dall-e-3",
  size: "1024x1024",
  quality: "hd",
  style: "vivid"
)

# Download image
require 'open-uri'
File.open('generated.png', 'wb') do |file|
  file.write(URI.open(image_url).read)
end
```

### Content Moderation

```ruby
result = RubyLLM.moderate("Some user-generated content here")

if result.flagged
  puts "Content flagged for: #{result.categories.keys}"
  
  # Check specific categories
  puts "Hate speech: #{result.categories[:hate]}"
  puts "Violence: #{result.categories[:violence]}"
  puts "Sexual: #{result.categories[:sexual]}"
end
```

### Model Selection

```ruby
# By explicit model name
chat = RubyLLM.chat(model: "gpt-4o")

# By provider prefix
chat = RubyLLM.chat(model: "anthropic/claude-3-5-sonnet-20241022")

# Auto-select from registry
chat = RubyLLM.chat(provider: :openai) # Uses default OpenAI model

# List available models
RubyLLM.models.list.each do |model|
  puts "#{model.name} - #{model.provider}"
end

# Find models by capability
vision_models = RubyLLM.models.with_capability(:vision)
function_calling_models = RubyLLM.models.with_capability(:tools)
```

## Model Registry

RubyLLM maintains a comprehensive registry of 800+ models với metadata:

```ruby
model = RubyLLM.models.find("gpt-4o")

model.name           # => "gpt-4o"
model.provider       # => :openai
model.capabilities   # => [:chat, :vision, :tools, :streaming]
model.context_window # => 128000
model.max_output     # => 16384
model.input_price    # => 2.50 per 1M tokens
model.output_price   # => 10.00 per 1M tokens
```

**Capabilities tracked:**
- `:chat` - Text chat
- `:vision` - Image/video understanding
- `:tools` - Function calling
- `:streaming` - Streaming responses
- `:json_mode` - Structured output
- `:embeddings` - Vector embeddings
- `:images` - Image generation
- `:audio` - Audio transcription

## Error Handling

```ruby
begin
  chat = RubyLLM.chat(model: "gpt-4o")
  response = chat.ask("Hello")
rescue RubyLLM::AuthenticationError => e
  # Invalid API key
  puts "Auth failed: #{e.message}"
rescue RubyLLM::RateLimitError => e
  # Rate limit exceeded
  puts "Rate limited, retry after: #{e.retry_after}"
rescue RubyLLM::ModelNotFoundError => e
  # Invalid model name
  puts "Model not found: #{e.message}"
rescue RubyLLM::ProviderError => e
  # General provider error
  puts "Provider error: #{e.message}"
rescue RubyLLM::Error => e
  # Catch-all for RubyLLM errors
  puts "RubyLLM error: #{e.message}"
end
```

## Advanced Configuration

### Per-Request Options

```ruby
chat = RubyLLM.chat(model: "gpt-4o")

response = chat.ask(
  "Your question",
  temperature: 0.7,        # Creativity (0.0-2.0)
  max_tokens: 1000,        # Response length limit
  top_p: 0.9,              # Nucleus sampling
  frequency_penalty: 0.5,  # Reduce repetition
  presence_penalty: 0.5,   # Encourage new topics
  stop: ["\n\n"],          # Stop sequences
  seed: 42                 # Reproducible outputs
)
```

### Custom HTTP Client

```ruby
RubyLLM.configure do |config|
  config.faraday_middleware = lambda do |conn|
    conn.request :retry, max: 5, interval: 1
    conn.request :authorization, 'Bearer', 'custom_token'
    conn.response :logger, Rails.logger, bodies: true
    conn.adapter Faraday.default_adapter
  end
end
```

### Timeouts & Retries

```ruby
RubyLLM.configure do |config|
  config.timeout = 120           # Request timeout (seconds)
  config.open_timeout = 10       # Connection timeout
  config.max_retries = 3         # Retry failed requests
  config.retry_interval = 2      # Seconds between retries
end
```

### Provider-Specific Configuration

```ruby
RubyLLM.configure do |config|
  # Azure OpenAI
  config.azure_api_base = "https://your-resource.openai.azure.com"
  config.azure_api_version = "2024-02-15-preview"
  config.azure_deployment_name = "gpt-4"
  
  # AWS Bedrock
  config.bedrock_region = "us-east-1"
  config.bedrock_access_key_id = ENV['AWS_ACCESS_KEY_ID']
  config.bedrock_secret_access_key = ENV['AWS_SECRET_ACCESS_KEY']
  
  # Vertex AI
  config.vertex_project_id = "my-project-123"
  config.vertex_location = "us-central1"
  
  # Ollama (local)
  config.ollama_api_base = "http://localhost:11434"
end
```

## Project Goals

### Short-term (Current - v1.x)

1. **Stability**: Bug fixes, comprehensive testing
2. **Provider Coverage**: Thêm providers mới (Cohere, AI21, etc.)
3. **Model Registry**: Update thường xuyên với models mới
4. **Documentation**: Cải thiện docs, thêm examples

### Mid-term (v2.x)

1. **Performance**: Connection pooling improvements
2. **Async Support**: Native async/await với Fibers
3. **Caching**: Response caching layer
4. **Monitoring**: Built-in metrics và tracing
5. **Rails 8**: Full compatibility với Rails 8

### Long-term (v3.x+)

1. **Agent Framework**: Multi-agent orchestration
2. **Fine-tuning**: Support fine-tuning workflows
3. **Vector Stores**: Built-in vector database integration
4. **RAG Pipelines**: Retrieval-Augmented Generation utilities
5. **Plugin System**: Extensible middleware architecture

## Community & Contribution

### Contributing

1. Fork repository
2. Create feature branch
3. Add tests với VCR cassettes
4. Follow Rubocop style guide
5. Submit pull request

**Areas for contribution:**
- New provider implementations
- Model registry updates
- Documentation improvements
- Bug fixes
- Performance optimizations

### Resources

- **Documentation**: https://rubyllm.com
- **GitHub Issues**: https://github.com/crmne/ruby_llm/issues
- **Discussions**: https://github.com/crmne/ruby_llm/discussions
- **Changelog**: https://github.com/crmne/ruby_llm/blob/main/CHANGELOG.md

### License

MIT License - free for personal and commercial use.

### Support

- **GitHub Issues**: Bug reports, feature requests
- **Email**: Liên hệ qua GitHub profile
- **Community**: Ruby community forums, Discord

## Success Metrics

### Adoption
- **RubyGems downloads**: Tracking monthly downloads
- **GitHub stars**: Community interest indicator
- **Production usage**: Number of apps deployed

### Quality
- **Test coverage**: Target >90%
- **Bug reports**: Resolution time <48h for critical issues
- **Documentation**: Completeness score

### Performance
- **Response times**: P50, P95, P99 latency metrics
- **Error rates**: <0.1% API errors
- **Uptime**: 99.9% availability (dependent on providers)

## Risks & Mitigation

### Technical Risks

1. **Provider API Changes**
   - Risk: Providers change APIs without notice
   - Mitigation: Comprehensive test suite, version pinning, quick response team

2. **Performance Bottlenecks**
   - Risk: Slow requests impact application performance
   - Mitigation: Async support, timeouts, connection pooling

3. **Dependency Issues**
   - Risk: Breaking changes in Faraday, Rails, etc.
   - Mitigation: Minimal dependencies, version constraints, CI matrix

### Business Risks

1. **Provider Pricing Changes**
   - Risk: Cost increases affect users
   - Mitigation: Document pricing, allow easy provider switching

2. **Deprecated Models**
   - Risk: Models retired by providers
   - Mitigation: Model registry updates, deprecation warnings

3. **Competitive Landscape**
   - Risk: Similar gems emerge
   - Mitigation: Focus on quality, community, comprehensive provider support

## Conclusion

RubyLLM aims to be the definitive Ruby gem cho LLM integration, providing:

- **Simplicity**: One API for all providers
- **Completeness**: Support for all major LLM capabilities
- **Reliability**: Production-ready with comprehensive testing
- **Flexibility**: Easy to extend and customize
- **Community**: Open source với active maintenance

**Design Philosophy:**
- Convention over configuration
- Minimal dependencies
- Rails-friendly but framework-agnostic
- Backward compatibility
- Clear, comprehensive documentation

**Target Users:**
- Ruby developers building LLM-powered applications
- Rails apps needing AI features
- Teams wanting provider flexibility
- Developers prototyping AI features quickly

RubyLLM enables Ruby developers to leverage cutting-edge AI models without dealing with the complexity of multiple provider APIs, focusing on building great applications instead of integration plumbing.
