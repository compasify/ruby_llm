# RubyLLM - Deployment Guide

## Cài Đặt

### Requirements

- Ruby >= 3.1.3
- Bundler >= 2.0

### Installation

Thêm vào Gemfile:

```ruby
gem 'ruby_llm'
```

Sau đó:

```bash
bundle install
```

## Configuration

### Basic Configuration

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  # Provider API Keys
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.gemini_api_key = ENV['GEMINI_API_KEY']
  
  # Default models
  config.default_model = 'gpt-4o'
  config.default_embedding_model = 'text-embedding-3-small'
end
```

### Provider-Specific Configuration

#### OpenAI

```ruby
config.openai_api_key = ENV['OPENAI_API_KEY']
config.openai_api_base = ENV['OPENAI_API_BASE']  # Optional, for proxies
config.openai_organization_id = ENV['OPENAI_ORG_ID']  # Optional
config.openai_project_id = ENV['OPENAI_PROJECT_ID']  # Optional
```

#### Anthropic

```ruby
config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
```

#### Google Gemini

```ruby
config.gemini_api_key = ENV['GEMINI_API_KEY']
config.gemini_api_base = ENV['GEMINI_API_BASE']  # Optional
```

#### Google VertexAI

```ruby
config.vertexai_project_id = ENV['VERTEXAI_PROJECT_ID']
config.vertexai_location = ENV['VERTEXAI_LOCATION']  # e.g., 'us-central1'
# Uses Application Default Credentials
```

#### AWS Bedrock

```ruby
config.bedrock_api_key = ENV['AWS_ACCESS_KEY_ID']
config.bedrock_secret_key = ENV['AWS_SECRET_ACCESS_KEY']
config.bedrock_region = ENV['AWS_REGION']
config.bedrock_session_token = ENV['AWS_SESSION_TOKEN']  # Optional
```

#### Azure OpenAI

```ruby
config.azure_api_base = ENV['AZURE_OPENAI_ENDPOINT']
config.azure_api_key = ENV['AZURE_OPENAI_KEY']
# OR
config.azure_ai_auth_token = ENV['AZURE_AI_TOKEN']
```

#### Local Providers (Ollama, GPUStack)

```ruby
# Ollama
config.ollama_api_base = 'http://localhost:11434/v1'

# GPUStack
config.gpustack_api_base = 'http://localhost:8080/v1'
config.gpustack_api_key = ENV['GPUSTACK_API_KEY']  # Optional
```

#### Other Providers

```ruby
config.deepseek_api_key = ENV['DEEPSEEK_API_KEY']
config.mistral_api_key = ENV['MISTRAL_API_KEY']
config.openrouter_api_key = ENV['OPENROUTER_API_KEY']
config.perplexity_api_key = ENV['PERPLEXITY_API_KEY']
config.xai_api_key = ENV['XAI_API_KEY']
```

### Connection Settings

```ruby
config.request_timeout = 300        # seconds
config.max_retries = 3
config.retry_interval = 0.1         # seconds
config.retry_backoff_factor = 2
config.retry_interval_randomness = 0.5
config.http_proxy = ENV['HTTP_PROXY']  # Optional
```

### Logging

```ruby
config.logger = Rails.logger        # Use Rails logger
config.log_file = $stdout           # Or file path
config.log_level = Logger::INFO     # DEBUG for verbose
config.log_stream_debug = false     # Enable stream chunk logging
```

Environment variable `RUBYLLM_DEBUG=true` enables debug logging.

## Rails Integration

### Install Generator

```bash
rails generate ruby_llm:install
```

Tạo:
- Migrations cho Chat, Message, ToolCall, Model tables
- Model files với `acts_as_*` declarations
- Initializer với configuration
- Installs ActiveStorage nếu cần

Options:

```bash
rails generate ruby_llm:install \
  --chat-model=Conversation \
  --message-model=ChatMessage \
  --tool-call-model=FunctionCall \
  --model-model=AiModel \
  --namespace=AI
```

### Chat UI Generator

```bash
rails generate ruby_llm:chat_ui
```

Tạo:
- Controllers cho chats và messages
- Views với Turbo streaming
- Routes
- Background job cho async responses
- Styles

### Upgrade Generators

Khi upgrade RubyLLM version:

```bash
# Upgrade to v1.7 (Rails-like API)
rails generate ruby_llm:upgrade_to_v1_7

# Upgrade to v1.9 (cached tokens, raw content)
rails generate ruby_llm:upgrade_to_v1_9

# Upgrade to v1.10 (thinking support)
rails generate ruby_llm:upgrade_to_v1_10
```

### Database Migrations

Sau khi run generators:

```bash
rails db:migrate
```

## Environment Setup

### Development

```bash
# .env.development
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
GEMINI_API_KEY=AI...
```

Sử dụng `dotenv` gem để load:

```ruby
# Gemfile
gem 'dotenv-rails', groups: [:development, :test]
```

### Production

#### Heroku

```bash
heroku config:set OPENAI_API_KEY=sk-...
heroku config:set ANTHROPIC_API_KEY=sk-ant-...
```

#### Docker

```dockerfile
ENV OPENAI_API_KEY=${OPENAI_API_KEY}
ENV ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
```

#### Kubernetes

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: llm-api-keys
type: Opaque
data:
  openai-api-key: c2stLi4u  # base64 encoded
  anthropic-api-key: c2stYW50Li4u
```

### CI/CD

```yaml
# .github/workflows/test.yml
env:
  OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
```

## Testing

### VCR Cassettes

RubyLLM sử dụng VCR để record API responses:

```ruby
# spec/support/vcr.rb
VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  config.hook_into :webmock
  config.filter_sensitive_data('<OPENAI_API_KEY>') { ENV['OPENAI_API_KEY'] }
end
```

### Re-recording Cassettes

```bash
# Specific providers
rake vcr:record[openai,anthropic]

# All providers
rake vcr:record[all]
```

### Running Tests

```bash
# All tests
bundle exec rspec

# Without generators (faster)
bundle exec rspec --tag '~generator'

# With specific Rails version
bundle exec appraisal rails-8.0 rspec
```

## Monitoring

### Logging

```ruby
RubyLLM.logger.info "Chat started"
```

### Token Tracking

```ruby
response = chat.ask("Hello")
puts response.input_tokens    # tokens sent
puts response.output_tokens   # tokens received
puts response.cached_tokens   # cached tokens (if any)
```

### Error Handling

```ruby
begin
  chat.ask("Hello")
rescue RubyLLM::RateLimitError => e
  # Handle rate limiting
  sleep(60)
  retry
rescue RubyLLM::AuthenticationError => e
  # Handle auth errors
  Rails.logger.error "Invalid API key"
rescue RubyLLM::ServerError => e
  # Handle provider errors
  Sentry.capture_exception(e)
end
```

## Performance

### Connection Pooling

Faraday handles connection pooling automatically. Reuse Chat instances khi có thể:

```ruby
# Good - reuse chat
chat = RubyLLM.chat
chat.ask("First question")
chat.ask("Second question")

# Avoid - new chat each time
RubyLLM.chat.ask("Question 1")
RubyLLM.chat.ask("Question 2")
```

### Streaming

Sử dụng streaming cho long responses:

```ruby
chat.ask("Write a long story") do |chunk|
  # Process incrementally
  broadcast_chunk(chunk.content)
end
```

### Async

Sử dụng Async gem cho concurrent requests:

```ruby
Async do
  results = [
    Async { RubyLLM.embed("text1") },
    Async { RubyLLM.embed("text2") },
    Async { RubyLLM.embed("text3") }
  ].map(&:wait)
end
```

## Security

### API Key Management

- Never commit API keys to source control
- Use environment variables or secrets management
- Rotate keys regularly
- Use separate keys for development/production

### Content Filtering

```ruby
# Check content safety before processing
result = RubyLLM.moderate(user_input)
if result.flagged?
  # Handle unsafe content
end
```

### Rate Limiting

Implement rate limiting in application:

```ruby
# Using rack-attack or similar
Rack::Attack.throttle('llm/ip', limit: 10, period: 60) do |req|
  req.ip if req.path.start_with?('/api/chat')
end
```

## Troubleshooting

### Common Issues

#### "Missing configuration for X"

```ruby
# Ensure provider is configured
RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY')
end
```

#### "Unknown model: X"

```ruby
# Check model exists
RubyLLM.models.find('gpt-4o')

# Or assume it exists
chat = RubyLLM.chat(
  model: 'custom-model',
  provider: :openai,
  assume_model_exists: true
)
```

#### Streaming not working

```ruby
# Ensure block is provided
chat.ask("Question") do |chunk|
  puts chunk.content  # Must have block!
end
```

### Debug Mode

```bash
RUBYLLM_DEBUG=true rails console
```

```ruby
RubyLLM.configure do |config|
  config.log_level = Logger::DEBUG
  config.log_stream_debug = true
end
```

## Liên Kết

- [Project Overview](./project-overview-pdr.md)
- [System Architecture](./system-architecture.md)
- [Code Standards](./code-standards.md)
- [Official Documentation](https://rubyllm.com)
