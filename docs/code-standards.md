# RubyLLM - Code Standards & Best Practices

**Version:** 1.11.0  
**Last Updated:** Feb 2026

## Ruby Style Guide

RubyLLM follows community Ruby style conventions với một số customizations.

### Rubocop Configuration

**Base Config (.rubocop.yml):**
```yaml
require:
  - rubocop-rspec

AllCops:
  TargetRubyVersion: 3.1
  NewCops: enable
  Exclude:
    - 'vendor/**/*'
    - 'tmp/**/*'
    - 'db/schema.rb'

Style/Documentation:
  Enabled: false  # Documentation via YARD comments

Layout/LineLength:
  Max: 120
  AllowedPatterns:
    - '\s*#'  # Allow long comments

Metrics/MethodLength:
  Max: 25
  CountAsOne: ['array', 'hash', 'heredoc']

Metrics/BlockLength:
  Exclude:
    - 'spec/**/*'
    - '*.gemspec'

Metrics/ClassLength:
  Max: 300
  CountAsOne: ['array', 'hash']

Style/StringLiterals:
  EnforcedStyle: single_quotes

Style/FrozenStringLiteralComment:
  Enabled: false

Naming/FileName:
  Exclude:
    - 'Gemfile'
    - 'Rakefile'
```

### Code Formatting Rules

**1. Indentation:**
```ruby
# GOOD: 2 spaces, no tabs
class Chat
  def ask(content)
    messages << Message.new(content)
    response = provider.chat(messages: messages)
    response
  end
end

# BAD: 4 spaces or tabs
class Chat
    def ask(content)
        # Wrong indentation
    end
end
```

**2. Method Definitions:**
```ruby
# GOOD: Descriptive names, single responsibility
def format_messages_for_openai(messages)
  messages.map { |msg| transform_message(msg) }
end

# BAD: Vague names, too many responsibilities
def fmt(m)
  # Unclear purpose
  m.map { |x| x.to_h }.tap { |y| log(y) }.compact.reject(&:empty?)
end
```

**3. Line Length:**
```ruby
# GOOD: Under 120 characters
response = connection.post('/chat/completions') do |req|
  req.body = { model: model_name, messages: messages }
end

# ACCEPTABLE: Long strings can wrap
error_message = "The requested model is not available. " \
                "Please check your subscription or try a different model."

# BAD: Exceeds 120 without reason
response = connection.post('/chat/completions') do |req|
  req.body = { model: model_name, messages: format_messages(messages), temperature: temperature, max_tokens: max_tokens, top_p: top_p }
end
```

**4. String Literals:**
```ruby
# GOOD: Single quotes for static strings
message = 'Hello, world!'
model_name = 'gpt-4o'

# GOOD: Double quotes for interpolation
message = "User asked: #{content}"
url = "https://api.openai.com/v1/models/#{model}"

# GOOD: Heredocs for multi-line
prompt = <<~TEXT
  You are a helpful assistant.
  Please respond concisely.
TEXT
```

## Naming Conventions

### Classes & Modules

```ruby
# GOOD: PascalCase, descriptive
class ChatConversation
class OpenAIProvider
module StreamingSupport

# BAD: Wrong casing or vague
class chatConversation
class Provider1
module Utils
```

### Methods & Variables

```ruby
# GOOD: snake_case, verb phrases for methods
def send_request
def format_message
def parse_response

user_input = "Hello"
api_response = {}

# BAD: camelCase or unclear
def sendRequest
def DoStuff
def x

userInput = "Hello"
resp = {}
```

### Constants

```ruby
# GOOD: SCREAMING_SNAKE_CASE
API_VERSION = "2024-02-15"
DEFAULT_TIMEOUT = 120
MAX_RETRIES = 3

# BAD: Wrong casing
ApiVersion = "2024-02-15"
default_timeout = 120
```

### Private Methods

```ruby
class Provider
  def chat(messages:)
    request = build_request(messages)
    send_request(request)
  end
  
  private
  
  # GOOD: Private methods below public interface
  def build_request(messages)
    # Implementation
  end
  
  def send_request(request)
    # Implementation
  end
end
```

## Class Structure

### Standard Class Layout

```ruby
class ExampleClass
  # 1. Constants
  API_VERSION = '1.0'
  
  # 2. Class variables
  @@instances = []
  
  # 3. Attr declarations
  attr_reader :name
  attr_accessor :status
  
  # 4. Class methods
  def self.create_default
    new(name: 'default')
  end
  
  # 5. Initialize
  def initialize(name:)
    @name = name
    @status = :active
  end
  
  # 6. Public instance methods
  def process
    validate!
    perform_work
    update_status
  end
  
  # 7. Private/protected methods
  private
  
  def validate!
    raise ArgumentError unless name
  end
  
  def perform_work
    # Implementation
  end
  
  protected
  
  def update_status
    @status = :complete
  end
end
```

### Module Organization

```ruby
module RubyLLM
  module Providers
    # GOOD: Nested modules for namespacing
    class OpenAI < Provider
      module ChatSupport
        def chat(messages:)
          # Implementation
        end
      end
      
      module EmbeddingSupport
        def embed(text:)
          # Implementation
        end
      end
      
      include ChatSupport
      include EmbeddingSupport
    end
  end
end
```

## Method Design

### Single Responsibility

```ruby
# GOOD: Each method does one thing
def create_chat_message(content)
  message = Message.new(role: 'user', content: content)
  validate_message(message)
  messages << message
  message
end

def send_to_provider(messages)
  request = build_request(messages)
  response = connection.post(endpoint, request)
  parse_response(response)
end

# BAD: Method does too much
def process(content)
  msg = Message.new(role: 'user', content: content)
  raise if msg.content.nil?
  messages << msg
  req = { model: @model, messages: messages.map(&:to_h) }
  res = Faraday.post("https://api.openai.com/v1/chat", req.to_json)
  JSON.parse(res.body)['choices'][0]['message']['content']
end
```

### Method Length

```ruby
# GOOD: Under 25 lines, focused purpose
def format_message_for_provider(message)
  base = {
    role: message.role,
    content: format_content(message.content)
  }
  
  base[:name] = message.name if message.name
  base[:tool_calls] = message.tool_calls if message.tool_calls
  
  base
end

# BAD: Over 25 lines, multiple responsibilities
def format_and_send(message)
  # 50+ lines of mixed logic
  # Formatting, validation, HTTP, parsing all mixed together
end
```

### Parameter Handling

```ruby
# GOOD: Keyword arguments with defaults
def chat(messages:, model: nil, temperature: 0.7, max_tokens: nil)
  # Implementation
end

# GOOD: Options hash for many parameters
def chat(messages:, **options)
  temperature = options[:temperature] || 0.7
  max_tokens = options[:max_tokens]
  # Implementation
end

# BAD: Too many positional arguments
def chat(messages, model, temp, tokens, top_p, freq, pres)
  # Hard to remember order
end
```

### Return Values

```ruby
# GOOD: Explicit returns for clarity
def find_model(name)
  return nil if name.nil?
  return models[name] if models.key?(name)
  
  fuzzy_match(name)
end

# GOOD: Implicit return for simple cases
def full_name
  "#{first_name} #{last_name}"
end

# BAD: Inconsistent returns
def process(input)
  if input.valid?
    perform_work(input)
    return true
  end
  false  # Mixing implicit and explicit
end
```

## Error Handling

### Exception Hierarchy

```ruby
# lib/ruby_llm/errors.rb
module RubyLLM
  class Error < StandardError; end
  
  # API errors
  class ProviderError < Error; end
  class AuthenticationError < ProviderError; end
  class RateLimitError < ProviderError
    attr_reader :retry_after
    
    def initialize(message, retry_after: nil)
      super(message)
      @retry_after = retry_after
    end
  end
  class ModelNotFoundError < ProviderError; end
  
  # Configuration errors
  class ConfigurationError < Error; end
  class MissingAPIKeyError < ConfigurationError; end
  
  # Usage errors
  class InvalidRequestError < Error; end
  class ToolExecutionError < Error; end
end
```

### Raising Exceptions

```ruby
# GOOD: Specific exception classes with messages
def validate_api_key!
  return if Configuration.instance.openai_api_key
  
  raise MissingAPIKeyError, 
        "OpenAI API key not configured. Set RubyLLM.configuration.openai_api_key"
end

def find_model!(name)
  model = find_model(name)
  return model if model
  
  raise ModelNotFoundError,
        "Model '#{name}' not found in registry. Available: #{available_models.join(', ')}"
end

# BAD: Generic exceptions or no message
def validate!
  raise "Invalid" unless valid?
end
```

### Exception Handling

```ruby
# GOOD: Catch specific exceptions
def fetch_with_retry
  retries = 0
  begin
    connection.get('/models')
  rescue RateLimitError => e
    retries += 1
    sleep(e.retry_after || 2**retries)
    retry if retries < 3
    raise
  rescue AuthenticationError => e
    logger.error("Authentication failed: #{e.message}")
    raise
  rescue ProviderError => e
    logger.warn("Provider error: #{e.message}")
    nil
  end
end

# BAD: Catch all exceptions
def fetch_data
  connection.get('/models')
rescue StandardError => e
  nil  # Swallows all errors, loses context
end
```

## Testing Standards

### RSpec Structure

```ruby
# GOOD: Descriptive, well-organized
RSpec.describe RubyLLM::Chat do
  let(:model) { 'gpt-4o' }
  let(:chat) { described_class.new(model: model) }
  
  describe '#ask' do
    context 'with a simple question' do
      it 'returns a response' do
        response = chat.ask('Hello')
        expect(response).to be_a(RubyLLM::Response)
        expect(response.text).not_to be_nil
      end
    end
    
    context 'with attachments' do
      it 'includes images in the request' do
        response = chat.ask('Describe this', images: ['test.jpg'])
        expect(response).to be_a(RubyLLM::Response)
      end
    end
    
    context 'when provider returns an error' do
      before do
        allow(chat.provider).to receive(:chat).and_raise(
          RubyLLM::AuthenticationError, 'Invalid API key'
        )
      end
      
      it 'raises the error' do
        expect { chat.ask('Hello') }.to raise_error(
          RubyLLM::AuthenticationError, /Invalid API key/
        )
      end
    end
  end
end

# BAD: Unclear, poorly organized
RSpec.describe RubyLLM::Chat do
  it 'works' do
    c = RubyLLM::Chat.new(model: 'gpt-4o')
    r = c.ask('Hello')
    expect(r.text).to eq('Hi')  # Brittle assertion
  end
end
```

### VCR Usage

```ruby
# GOOD: Use VCR for HTTP interactions
RSpec.describe RubyLLM::Providers::OpenAI, :vcr do
  let(:provider) { described_class.new(model: 'gpt-4o') }
  
  it 'sends a chat request', vcr: { cassette_name: 'openai/chat' } do
    messages = [RubyLLM::Message.new(role: 'user', content: 'Test')]
    response = provider.chat(messages: messages)
    
    expect(response).to be_a(RubyLLM::Response)
  end
end

# spec/fixtures/vcr_cassettes/openai/chat.yml created automatically
```

### Test Coverage

```ruby
# GOOD: Test happy path + edge cases
describe '#format_message' do
  it 'formats a text-only message' do
    msg = Message.new(role: 'user', content: 'Hello')
    result = format_message(msg)
    expect(result[:role]).to eq('user')
    expect(result[:content]).to eq('Hello')
  end
  
  it 'formats a message with images' do
    msg = Message.new(
      role: 'user',
      content: [
        Content.new(type: 'text', text: 'Describe'),
        Content.new(type: 'image_url', image_url: 'http://example.com/img.jpg')
      ]
    )
    result = format_message(msg)
    expect(result[:content]).to be_an(Array)
    expect(result[:content].size).to eq(2)
  end
  
  it 'handles nil content' do
    msg = Message.new(role: 'user', content: nil)
    result = format_message(msg)
    expect(result[:content]).to be_nil
  end
end
```

## Documentation Standards

### YARD Comments

```ruby
# GOOD: Document public API with YARD
module RubyLLM
  # Create a new chat conversation with a language model.
  #
  # @param model [String, nil] the model name (e.g., 'gpt-4o', 'claude-3-5-sonnet')
  # @param provider [Symbol, nil] the provider to use (:openai, :anthropic, etc.)
  # @param system [String, nil] system prompt to set conversation context
  # @param temperature [Float] sampling temperature (0.0-2.0)
  # @param max_tokens [Integer, nil] maximum tokens in response
  # @return [Chat] a new chat conversation instance
  # @raise [ModelNotFoundError] if model is invalid
  # @raise [MissingAPIKeyError] if provider API key not configured
  #
  # @example Simple chat
  #   chat = RubyLLM.chat(model: 'gpt-4o')
  #   response = chat.ask('Hello')
  #
  # @example With system prompt
  #   chat = RubyLLM.chat(
  #     model: 'claude-3-5-sonnet-20241022',
  #     system: 'You are a helpful coding assistant'
  #   )
  #
  def self.chat(model: nil, provider: nil, system: nil, **options)
    # Implementation
  end
end
```

### README Documentation

```ruby
# GOOD: Clear examples in README
# ## Usage
#
# ### Basic Chat
# ```ruby
# chat = RubyLLM.chat(model: "gpt-4o")
# response = chat.ask("What is Ruby?")
# puts response.text
# ```
#
# ### Streaming Responses
# ```ruby
# chat.stream("Tell me a story") do |chunk|
#   print chunk.text
# end
# ```
```

### Inline Comments

```ruby
# GOOD: Explain WHY, not WHAT
def retry_with_backoff
  attempts = 0
  begin
    yield
  rescue RateLimitError => e
    attempts += 1
    # Exponential backoff: 1s, 2s, 4s, 8s...
    # This prevents overwhelming the provider during rate limit periods
    sleep(2**attempts)
    retry if attempts < 5
    raise
  end
end

# BAD: Comments state the obvious
def add_message(msg)
  # Add message to messages array
  messages << msg
end
```

## Provider Implementation Standards

### Standard Provider Structure

```ruby
module RubyLLM
  module Providers
    class NewProvider < Provider
      # 1. Configuration
      def api_base
        Configuration.instance.new_provider_api_base ||
          'https://api.newprovider.com'
      end
      
      def api_key
        Configuration.instance.new_provider_api_key
      end
      
      # 2. Required methods
      def chat(messages:, **options)
        response = connection.post('/chat') do |req|
          req.body = build_chat_request(messages, **options)
        end
        
        parse_chat_response(response.body)
      end
      
      def embed(text:, **options)
        # Implementation
      end
      
      # 3. Provider-specific transformations
      private
      
      def build_chat_request(messages, **options)
        {
          model: model_name,
          messages: format_messages(messages),
          temperature: options[:temperature],
          max_tokens: options[:max_tokens]
        }.compact
      end
      
      def format_messages(messages)
        messages.map do |msg|
          {
            role: role_mapping(msg.role),
            content: format_content(msg.content)
          }
        end
      end
      
      def role_mapping(role)
        # Transform roles if provider uses different names
        case role
        when 'user' then 'user'
        when 'assistant' then 'assistant'
        when 'system' then 'system'
        end
      end
      
      def parse_chat_response(body)
        Response.new(
          text: body.dig('result', 'text'),
          finish_reason: body['finish_reason'],
          usage: parse_usage(body['usage'])
        )
      end
    end
  end
end
```

### Provider Testing Template

```ruby
RSpec.describe RubyLLM::Providers::NewProvider, :vcr do
  let(:provider) { described_class.new(model: 'test-model') }
  
  describe '#chat' do
    it 'sends a basic chat request' do
      messages = [
        RubyLLM::Message.new(role: 'user', content: 'Hello')
      ]
      
      response = provider.chat(messages: messages)
      
      expect(response).to be_a(RubyLLM::Response)
      expect(response.text).not_to be_nil
    end
    
    it 'handles streaming' do
      messages = [
        RubyLLM::Message.new(role: 'user', content: 'Count to 5')
      ]
      
      chunks = []
      provider.stream(messages: messages) do |chunk|
        chunks << chunk
      end
      
      expect(chunks).not_to be_empty
    end
    
    it 'includes tool calls if supported' do
      tool = create_test_tool
      messages = [
        RubyLLM::Message.new(role: 'user', content: 'Use the tool')
      ]
      
      response = provider.chat(messages: messages, tools: [tool])
      
      # Provider-specific assertions
    end
  end
  
  describe '#embed' do
    it 'generates embeddings' do
      embedding = provider.embed(text: 'Test text')
      
      expect(embedding.vector).to be_an(Array)
      expect(embedding.dimensions).to be > 0
    end
  end
end
```

## Performance Patterns

### Lazy Loading

```ruby
# GOOD: Lazy load expensive resources
class Chat
  def provider
    @provider ||= resolve_provider
  end
  
  def connection
    @connection ||= build_connection
  end
end

# BAD: Eager loading
class Chat
  def initialize
    @provider = resolve_provider  # May not be needed
    @connection = build_connection  # Immediate connection
  end
end
```

### Memoization

```ruby
# GOOD: Memoize expensive computations
class Models
  def list
    @list ||= load_models_from_yaml
  end
  
  def find(name)
    @cache ||= {}
    @cache[name] ||= search_models(name)
  end
end

# GOOD: Clear cache when needed
def reload!
  @list = nil
  @cache = nil
end
```

### Efficient Iterations

```ruby
# GOOD: Use lazy enumerators for large collections
def process_large_dataset
  dataset.lazy
    .select { |item| item.valid? }
    .map { |item| transform(item) }
    .first(100)
end

# GOOD: Use each instead of map when return value not needed
def log_all_messages
  messages.each { |msg| logger.info(msg) }
end

# BAD: Unnecessary array allocations
def log_all_messages
  messages.map { |msg| logger.info(msg) }  # Creates unused array
end
```

## Security Best Practices

### API Key Handling

```ruby
# GOOD: Never log or expose API keys
def connection
  Faraday.new(api_base) do |conn|
    conn.request :authorization, 'Bearer', api_key
    conn.response :logger do |logger|
      logger.filter(/Authorization: .+/, 'Authorization: [FILTERED]')
    end
  end
end

# GOOD: Validate API keys exist before use
def validate_api_key!
  return if api_key.present?
  
  raise MissingAPIKeyError,
        "API key not configured for #{provider_name}"
end

# BAD: Exposing keys in logs
def debug_request
  Rails.logger.debug("Sending request with key: #{api_key}")
end
```

### Input Validation

```ruby
# GOOD: Validate and sanitize inputs
def set_temperature(value)
  raise InvalidRequestError, 'Temperature must be numeric' unless value.is_a?(Numeric)
  raise InvalidRequestError, 'Temperature must be 0.0-2.0' unless (0.0..2.0).cover?(value)
  
  @temperature = value
end

# GOOD: Prevent injection attacks
def build_prompt(user_input)
  # Escape special characters if needed
  sanitized = user_input.gsub(/[<>]/, '')
  "User asked: #{sanitized}"
end
```

### File Handling

```ruby
# GOOD: Validate file paths and types
def attach_file(path)
  raise InvalidRequestError, 'File does not exist' unless File.exist?(path)
  raise InvalidRequestError, 'File too large' if File.size(path) > 100.megabytes
  
  mime_type = Marcel::MimeType.for(Pathname.new(path))
  raise InvalidRequestError, 'Unsupported file type' unless allowed_mime_types.include?(mime_type)
  
  Attachment.new(path)
end

def allowed_mime_types
  %w[image/jpeg image/png image/gif application/pdf text/plain text/csv]
end
```

## Git Commit Standards

### Commit Message Format

```
type(scope): subject

body (optional)

footer (optional)
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Test additions or changes
- `chore`: Build process, dependencies, etc.

**Examples:**
```
feat(providers): add support for xAI Grok models

Implements chat, embeddings, and streaming for xAI provider.
Includes tests with VCR cassettes.

Closes #123

---

fix(streaming): handle SSE parsing for empty chunks

Some providers send empty data: lines which caused parsing errors.
Now skips empty chunks gracefully.

---

docs: update README with image generation examples

---

test(openai): add VCR cassette for tool calling

---

chore: update Faraday to 2.9
```

## Code Review Checklist

### Before Submitting PR

- [ ] All tests pass (`bundle exec rspec`)
- [ ] Rubocop passes (`bundle exec rubocop`)
- [ ] Documentation updated (README, YARD comments)
- [ ] CHANGELOG.md updated
- [ ] VCR cassettes recorded for new HTTP interactions
- [ ] No API keys or sensitive data in code or VCR cassettes
- [ ] Code follows project conventions
- [ ] New features have tests
- [ ] Public API has YARD documentation

### During Code Review

**Check for:**
- Single Responsibility Principle violations
- Missing error handling
- Unclear variable/method names
- Overly complex logic
- Missing tests
- Performance issues (N+1 queries, unnecessary allocations)
- Security concerns (injection, exposed credentials)
- Inconsistent patterns with existing code

## Rails Integration Standards

### Generator Structure

```ruby
# lib/generators/ruby_llm/install_generator.rb
module RubyLLM
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)
      
      def copy_initializer
        template 'initializer.rb', 'config/initializers/ruby_llm.rb'
      end
      
      def create_migrations
        rails_command 'generate migration CreateRubyLlmTables'
      end
      
      def show_readme
        readme 'README' if behavior == :invoke
      end
    end
  end
end
```

### Migration Standards

```ruby
# GOOD: Reversible migration with proper types
class CreateRubyLlmTables < ActiveRecord::Migration[7.1]
  def change
    create_table :conversations do |t|
      t.string :model_name, null: false
      t.text :system_prompt
      t.timestamps
    end
    
    create_table :chat_messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content
      t.json :tool_calls, default: []
      t.timestamps
      
      t.index [:conversation_id, :created_at]
    end
  end
end
```

### ActiveRecord Extensions

```ruby
# GOOD: Clean module integration
module RubyLLM
  module ActiveRecord
    module ChatMethods
      extend ActiveSupport::Concern
      
      included do
        has_many :messages, dependent: :destroy
        validates :model_name, presence: true
      end
      
      def ask(content, **options)
        # Implementation
      end
      
      class_methods do
        def with_model(model_name)
          where(model_name: model_name)
        end
      end
    end
  end
end
```

## Deprecation Policy

### Announcing Deprecations

```ruby
# GOOD: Clear deprecation warning
def old_method
  warn "[DEPRECATION] `old_method` is deprecated and will be removed in v2.0. " \
       "Use `new_method` instead.", uplevel: 1
  new_method
end

# GOOD: Deprecation with version info
module RubyLLM
  def self.configure_provider(provider, **options)
    warn <<~WARNING
      [DEPRECATION] RubyLLM.configure_provider is deprecated since v1.5.0
      and will be removed in v2.0.0.
      
      Use RubyLLM.configure instead:
        RubyLLM.configure do |config|
          config.#{provider}_api_key = '...'
        end
    WARNING
    
    # Fallback implementation
  end
end
```

### Version Compatibility

```ruby
# GOOD: Graceful fallback for deprecated options
def chat(messages:, **options)
  # Support old 'temp' parameter, prefer 'temperature'
  if options.key?(:temp) && !options.key?(:temperature)
    warn "[DEPRECATION] Option 'temp' is deprecated. Use 'temperature'.", uplevel: 1
    options[:temperature] = options.delete(:temp)
  end
  
  # Implementation
end
```

## Summary of Key Standards

1. **Ruby Style**: Follow community conventions + Rubocop
2. **Naming**: snake_case methods/vars, PascalCase classes, SCREAMING_SNAKE_CASE constants
3. **Methods**: Single responsibility, <25 lines, keyword arguments
4. **Error Handling**: Specific exceptions, clear messages
5. **Testing**: RSpec + VCR, test happy path + edge cases
6. **Documentation**: YARD for public API, inline comments for WHY
7. **Providers**: Standard structure, format/parse transformations
8. **Performance**: Lazy loading, memoization, efficient iterations
9. **Security**: Never expose API keys, validate inputs, sanitize files
10. **Git**: Conventional commits, descriptive messages

**Philosophy:**
- **Readability > Cleverness**: Code should be obvious
- **Convention > Configuration**: Follow Ruby/Rails patterns
- **Explicit > Implicit**: Be clear about intent
- **Simple > Complex**: Prefer straightforward solutions
- **Tested > Untested**: All code has tests
