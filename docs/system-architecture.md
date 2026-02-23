# RubyLLM - System Architecture

**Version:** 1.11.0  
**Last Updated:** Feb 2026

## Architectural Overview

RubyLLM sử dụng **Provider Abstraction Pattern** để tạo unified interface cho multiple LLM providers, cho phép developers sử dụng một API duy nhất thay vì phải học 13+ provider APIs khác nhau.

### High-Level Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                     Application Layer                         │
│  (Rails apps, Sinatra, standalone Ruby scripts)              │
└─────────────────────────┬─────────────────────────────────────┘
                          │
                          │ RubyLLM Public API
                          ▼
┌───────────────────────────────────────────────────────────────┐
│                     API Facade Layer                          │
│  RubyLLM.chat()  .paint()  .embed()  .transcribe()          │
│  .moderate()     .models()                                    │
└─────────────────────────┬─────────────────────────────────────┘
                          │
                          │ Delegates to
                          ▼
┌───────────────────────────────────────────────────────────────┐
│                     Core Domain Layer                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │   Chat   │  │  Tool    │  │ Message  │  │ Content  │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │Attachment│  │Streaming │  │  Models  │  │  Config  │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
└─────────────────────────┬─────────────────────────────────────┘
                          │
                          │ Uses
                          ▼
┌───────────────────────────────────────────────────────────────┐
│                     Provider Layer                            │
│  ┌─────────────────────────────────────────────────────┐     │
│  │          Base Provider (Abstract)                   │     │
│  │  - connection management                             │     │
│  │  - error handling                                    │     │
│  │  - streaming support                                 │     │
│  └─────────────────────────────────────────────────────┘     │
│         ▲        ▲        ▲        ▲        ▲                │
│         │        │        │        │        │                │
│  ┌──────┴──┐ ┌──┴──┐ ┌───┴───┐ ┌──┴──┐ ┌───┴────┐          │
│  │ OpenAI  │ │Anthro│ │Gemini │ │Azure│ │Bedrock │ ... (13) │
│  └─────────┘ └─────┘ └───────┘ └─────┘ └────────┘          │
└─────────────────────────┬─────────────────────────────────────┘
                          │
                          │ HTTP via Faraday
                          ▼
┌───────────────────────────────────────────────────────────────┐
│                     HTTP Layer                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │             Faraday Connection                        │    │
│  │  - Connection pooling                                 │    │
│  │  - Automatic retries                                  │    │
│  │  - Request/response middleware                        │    │
│  │  - JSON encoding/decoding                             │    │
│  │  - Authentication headers                             │    │
│  └──────────────────────────────────────────────────────┘    │
└─────────────────────────┬─────────────────────────────────────┘
                          │
                          │ HTTPS Requests
                          ▼
┌───────────────────────────────────────────────────────────────┐
│              External LLM Provider APIs                       │
│  OpenAI    Anthropic    Google    AWS    Microsoft    ...    │
└───────────────────────────────────────────────────────────────┘
```

## Component Architecture

### 1. API Facade Layer

**Purpose**: Entry point cho developers, tạo instances của core components.

**Responsibilities:**
- Public API methods
- Provider resolution
- Model name parsing
- Configuration access

**Key Components:**
```ruby
# lib/ruby_llm.rb
module RubyLLM
  # Factory method cho Chat instances
  def self.chat(model: nil, provider: nil, **options)
    resolved_model = models.find(model) || models.default_for_provider(provider)
    resolved_provider = resolve_provider(resolved_model.provider)
    
    Chat.new(
      model: resolved_model.name,
      provider: resolved_provider,
      **options
    )
  end
  
  # Direct image generation
  def self.paint(prompt:, model: nil, **options)
    provider = resolve_provider_for_model(model)
    provider.paint(prompt: prompt, **options)
  end
  
  # Direct embeddings
  def self.embed(text: nil, texts: nil, model: nil, **options)
    provider = resolve_provider_for_model(model)
    
    if texts
      provider.embed_batch(texts: texts, **options)
    else
      provider.embed(text: text, **options)
    end
  end
end
```

### 2. Core Domain Layer

#### Chat Conversation Management

**Purpose**: Manage conversation state và coordinate với providers.

```ruby
# lib/ruby_llm/chat.rb
class Chat
  attr_reader :model, :provider, :messages, :tools, :system_prompt
  
  # State: Conversation history
  @messages = []           # Array<Message>
  @tools = []              # Array<Tool class>
  @system_prompt = nil     # String
  
  # Configuration
  @temperature = 0.7
  @max_tokens = nil
  @top_p = nil
  
  # Public API
  def ask(content, **options)
    # 1. Add user message
    # 2. Build request with tools, attachments
    # 3. Call provider.chat()
    # 4. Add assistant response
    # 5. Handle tool calls if present
    # 6. Return response
  end
  
  def stream(content, **options, &block)
    # Similar flow but yields chunks
  end
  
  def with_tool(tool_class)
    # Register tool for function calling
  end
end
```

**State Machine:**
```
┌─────────────┐
│ Initialized │
└──────┬──────┘
       │
       │ .ask() or .stream()
       ▼
┌─────────────────┐
│ Building Request│
└──────┬──────────┘
       │
       │ Include: messages, tools, attachments
       ▼
┌──────────────┐
│Calling API   │
└──────┬───────┘
       │
       ├─────────► Tool calls? ──Yes──► Execute tools ──► Call API again
       │                                      ▲              │
       │                                      └──────────────┘
       No
       │
       ▼
┌──────────────┐
│Return Response│
└───────────────┘
```

#### Message & Content Structure

**Purpose**: Represent multimodal conversation messages.

```ruby
# lib/ruby_llm/message.rb
class Message
  attr_reader :role, :content, :tool_calls, :name
  
  # role: "user" | "assistant" | "system" | "tool"
  # content: String | Array<Content>
  # tool_calls: Array<ToolCall>
  # name: String (for tool responses)
  
  def to_openai
    # Transform to OpenAI format
  end
  
  def to_anthropic
    # Transform to Anthropic format
  end
end

# lib/ruby_llm/content.rb
class Content
  attr_reader :type, :text, :image_url, :tool_call_id
  
  # type: "text" | "image_url" | "tool_result"
end
```

**Content Types:**
```
Message
  ├─ text: String
  └─ content: Array<Content>
       ├─ Content(type: "text", text: "...")
       ├─ Content(type: "image_url", image_url: "...")
       └─ Content(type: "tool_result", tool_call_id: "...", content: "...")
```

#### Tool System

**Purpose**: Function calling với automatic execution.

**Architecture:**
```
┌─────────────────────────────────────────────────────────┐
│                     Tool Definition                     │
│  class WeatherTool < RubyLLM::Tool                     │
│    description "Get weather"                            │
│    param :location, type: 'string'                      │
│    def execute(location:); ...; end                     │
│  end                                                     │
└─────────────────────────────────────────────────────────┘
                          │
                          │ .to_schema()
                          ▼
┌─────────────────────────────────────────────────────────┐
│                     JSON Schema                         │
│  {                                                      │
│    type: "function",                                    │
│    function: {                                          │
│      name: "weather_tool",                              │
│      parameters: { type: "object", ... }                │
│    }                                                     │
│  }                                                       │
└─────────────────────────────────────────────────────────┘
                          │
                          │ Sent to LLM
                          ▼
┌─────────────────────────────────────────────────────────┐
│                   LLM Returns Tool Call                 │
│  {                                                      │
│    id: "call_123",                                      │
│    name: "weather_tool",                                │
│    arguments: { location: "NYC" }                       │
│  }                                                       │
└─────────────────────────────────────────────────────────┘
                          │
                          │ Chat executes tool
                          ▼
┌─────────────────────────────────────────────────────────┐
│                   Tool Execution                        │
│  tool = WeatherTool.new                                 │
│  result = tool.execute(location: "NYC")                 │
│  # => { temperature: 72, condition: "Sunny" }           │
└─────────────────────────────────────────────────────────┘
                          │
                          │ Add tool result to messages
                          ▼
┌─────────────────────────────────────────────────────────┐
│                 Follow-up API Call                      │
│  messages << {                                          │
│    role: "tool",                                        │
│    tool_call_id: "call_123",                            │
│    content: '{"temperature":72,"condition":"Sunny"}'    │
│  }                                                       │
│  # LLM generates final response using tool output       │
└─────────────────────────────────────────────────────────┘
```

#### Model Registry

**Purpose**: Central database of 800+ models với capability metadata.

**Data Structure:**
```yaml
# config/models.yml
openai:
  gpt-4o:
    provider: openai
    capabilities: [chat, vision, tools, streaming, json_mode]
    context_window: 128000
    max_output: 16384
    input_price: 2.50
    output_price: 10.00
    
  gpt-4o-mini:
    provider: openai
    capabilities: [chat, vision, tools, streaming, json_mode]
    context_window: 128000
    max_output: 16384
    input_price: 0.15
    output_price: 0.60
```

**Resolution Logic:**
```
Model Name Input
      │
      ▼
┌─────────────────────┐
│ Has provider prefix?│──Yes──► Extract provider + model
│ (e.g. "openai/...")  │        │
└─────────────────────┘        │
      │ No                      │
      ▼                         │
┌─────────────────────┐        │
│ Exact match in      │        │
│ registry?           │──Yes───┼─────► Return Model
└─────────────────────┘        │
      │ No                      │
      ▼                         │
┌─────────────────────┐        │
│ Fuzzy match         │        │
│ (substring search)  │──Found─┘
└─────────────────────┘
      │ Not Found
      ▼
┌─────────────────────┐
│ Use default model   │
│ for configured      │
│ provider            │
└─────────────────────┘
```

### 3. Provider Layer

#### Provider Base Class

**Purpose**: Abstract interface + shared utilities.

```ruby
# lib/ruby_llm/provider.rb
class Provider
  # Abstract methods (must implement)
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
  
  # Shared utilities
  include Streaming  # SSE streaming support
  
  def connection
    @connection ||= Faraday.new(api_base) do |conn|
      configure_middleware(conn)
    end
  end
  
  def handle_response(response)
    case response.status
    when 200..299 then parse_success(response)
    when 401 then raise AuthenticationError
    when 429 then raise RateLimitError
    when 404 then raise ModelNotFoundError
    else raise ProviderError
    end
  end
end
```

#### Provider Implementation Pattern

**Each provider implements:**

1. **API Configuration**
   - `api_base` - Base URL
   - `api_key` - Authentication
   - Provider-specific headers

2. **Request Building**
   - `build_chat_request(messages, **options)` - Transform to provider format
   - `format_messages(messages)` - Message structure conversion
   - `format_tools(tools)` - Tool schema conversion
   - `format_attachments(attachments)` - Multimodal content

3. **Response Parsing**
   - `parse_chat_response(body)` - Extract text, tool calls, usage
   - `parse_embedding_response(body)` - Extract vectors
   - `parse_image_response(body)` - Extract image URLs

4. **Streaming Support**
   - `stream(messages:, **options, &block)` - SSE parsing
   - `handle_stream_chunk(chunk)` - Incremental updates

**Example: OpenAI Provider**
```ruby
module RubyLLM
  module Providers
    class OpenAI < Provider
      def api_base
        'https://api.openai.com/v1'
      end
      
      def chat(messages:, **options)
        response = connection.post('/chat/completions') do |req|
          req.body = {
            model: model_name,
            messages: format_messages(messages),
            tools: format_tools(options[:tools]),
            temperature: options[:temperature],
            max_tokens: options[:max_tokens]
          }.compact
        end
        
        parse_chat_response(response.body)
      end
      
      private
      
      def format_messages(messages)
        messages.map do |msg|
          {
            role: msg.role,
            content: msg.content.is_a?(String) ? msg.content : format_content(msg.content),
            tool_calls: msg.tool_calls
          }.compact
        end
      end
      
      def format_content(content)
        content.map do |part|
          case part.type
          when "text"
            { type: "text", text: part.text }
          when "image_url"
            { type: "image_url", image_url: { url: part.image_url } }
          end
        end
      end
    end
  end
end
```

### 4. HTTP Layer

**Faraday Connection Management**

```ruby
def connection
  @connection ||= Faraday.new(api_base) do |conn|
    # Request middleware
    conn.request :authorization, 'Bearer', api_key
    conn.request :json  # Auto-encode JSON bodies
    conn.request :retry,
      max: max_retries,
      interval: retry_interval,
      retry_statuses: [429, 500, 502, 503, 504]
    
    # Response middleware
    conn.response :json  # Auto-decode JSON responses
    conn.response :logger, logger, bodies: false
    
    # Adapter
    conn.adapter Faraday.default_adapter
  end
end
```

**Middleware Pipeline:**
```
Request
  │
  ├─► Authorization: Add API key header
  │
  ├─► JSON: Encode body to JSON
  │
  ├─► Retry: Retry on 429/5xx with backoff
  │
  ▼
HTTP Request to Provider
  │
  ▼
HTTP Response from Provider
  │
  ├─► Logger: Log request/response (no bodies)
  │
  ├─► JSON: Decode JSON response
  │
  ▼
Response Object
```

## Data Flow Diagrams

### Chat Request Flow

```
User Code
  │
  │ chat.ask("Question", images: ["img.jpg"])
  ▼
┌──────────────────────────────────────────────────────────┐
│ Chat#ask                                                 │
│   1. Create Message(role: 'user', content: "Question")  │
│   2. Attach images as Content objects                    │
│   3. Append to messages array                            │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│ Chat#build_request                                       │
│   - Collect messages, system_prompt, tools               │
│   - Merge with options (temperature, max_tokens, etc.)  │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│ Provider#chat                                            │
│   - Format messages to provider-specific structure       │
│   - Format tools to provider schema                      │
│   - Build HTTP request body                              │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│ Faraday Connection                                       │
│   POST /chat/completions                                 │
│   Headers: Authorization, Content-Type                   │
│   Body: { model, messages, tools, temperature, ... }     │
└────────────────────────┬─────────────────────────────────┘
                         │
                         │ HTTPS
                         ▼
┌──────────────────────────────────────────────────────────┐
│ LLM Provider API                                         │
│   - Processes request                                    │
│   - Generates response                                   │
│   - Returns JSON                                         │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│ Provider#parse_chat_response                             │
│   - Extract text, tool_calls, finish_reason, usage       │
│   - Create Response object                               │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│ Chat#handle_response                                     │
│   - Check for tool_calls                                 │
│   - If present: execute tools → repeat request           │
│   - If not: add assistant message, return response       │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
                    User Code
                 (response.text)
```

### Streaming Flow

```
User Code
  │
  │ chat.stream("Question") { |chunk| print chunk.text }
  ▼
┌──────────────────────────────────────────────────────────┐
│ Chat#stream                                              │
│   - Build request with stream: true                      │
│   - Call provider.stream()                               │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│ Provider#stream                                          │
│   - Set up SSE handler                                   │
│   - Make streaming HTTP request                          │
└────────────────────────┬─────────────────────────────────┘
                         │
                         │ SSE Stream
                         ▼
┌──────────────────────────────────────────────────────────┐
│ Faraday on_data callback                                 │
│   - Receives chunks: "data: {...}\n\n"                   │
│   - Parse each line                                      │
└────────────────────────┬─────────────────────────────────┘
                         │
                         │ For each chunk
                         ▼
┌──────────────────────────────────────────────────────────┐
│ Provider#handle_stream_chunk                             │
│   - Parse JSON                                           │
│   - Extract delta (text, tool_calls, finish_reason)      │
│   - Create StreamChunk object                            │
└────────────────────────┬─────────────────────────────────┘
                         │
                         │ yield chunk
                         ▼
                    User Block
              print chunk.text (incremental)
```

### Tool Execution Flow

```
User: "What's the weather in NYC?"
  │
  ▼
Chat.ask() → Provider.chat()
  │
  ▼
LLM Response:
{
  "tool_calls": [
    {
      "id": "call_123",
      "type": "function",
      "function": {
        "name": "weather_tool",
        "arguments": "{\"location\":\"NYC\"}"
      }
    }
  ]
}
  │
  ▼
Chat detects tool_calls
  │
  ├─► Find Tool class: WeatherTool
  │
  ├─► Instantiate: tool = WeatherTool.new
  │
  ├─► Execute: result = tool.execute(location: "NYC")
  │   └─► Returns: { temperature: 72, condition: "Sunny" }
  │
  ├─► Create tool result message:
  │   Message(
  │     role: "tool",
  │     tool_call_id: "call_123",
  │     content: '{"temperature":72,"condition":"Sunny"}'
  │   )
  │
  └─► Append to messages, call provider.chat() again
       │
       ▼
   LLM Response:
   "The weather in NYC is currently 72°F and sunny."
```

## Provider Capability Matrix

### Full Feature Matrix

| Provider | Chat | Vision | Tools | Streaming | JSON | Embed | Images | Audio | Moderate |
|----------|------|--------|-------|-----------|------|-------|--------|-------|----------|
| **OpenAI** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Anthropic** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ |
| **Gemini** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ |
| **Azure** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Bedrock** | ✓ | Varies | Varies | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| **VertexAI** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ | ✗ |
| **DeepSeek** | ✓ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| **Mistral** | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ |
| **Ollama** | ✓ | ✓ | ✗ | ✓ | ✗ | ✓ | ✗ | ✗ | ✗ |
| **GPUStack** | ✓ | ✓ | ✗ | ✓ | ✗ | ✓ | ✗ | ✗ | ✗ |
| **OpenRouter** | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| **Perplexity** | ✓ | ✗ | ✗ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **xAI** | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |

### Provider-Specific Details

#### OpenAI
- **Endpoint**: `https://api.openai.com/v1`
- **Auth**: Bearer token
- **Message Format**: OpenAI standard (role + content array)
- **Tool Format**: OpenAI function calling schema
- **Streaming**: Server-Sent Events (SSE)
- **Specialties**: Most comprehensive feature set, de facto standard API format

#### Anthropic
- **Endpoint**: `https://api.anthropic.com/v1/messages`
- **Auth**: x-api-key header
- **Message Format**: Anthropic Messages API (system prompt separate)
- **Tool Format**: Similar to OpenAI but tool results sent as user messages
- **Streaming**: SSE với incremental content_block deltas
- **Specialties**: Excellent vision capabilities, high context window (200K)

#### Google Gemini
- **Endpoint**: `https://generativelanguage.googleapis.com/v1`
- **Auth**: API key in query params
- **Message Format**: Parts-based structure
- **Tool Format**: Function declarations với inline_data
- **Streaming**: SSE với streaming generateContent
- **Specialties**: Strong multimodal, document understanding (PDF, video)

#### AWS Bedrock
- **Endpoint**: `https://bedrock-runtime.{region}.amazonaws.com`
- **Auth**: AWS Signature V4
- **Message Format**: Varies by model (Claude, Llama, Mistral, etc.)
- **Specialties**: Enterprise deployment, VPC integration, multiple model families

#### Google Vertex AI
- **Endpoint**: `https://{location}-aiplatform.googleapis.com/v1`
- **Auth**: Google Cloud credentials (service account)
- **Message Format**: Similar to Gemini (Parts-based)
- **Specialties**: Enterprise features, audit logging, IAM integration

#### DeepSeek
- **Endpoint**: `https://api.deepseek.com`
- **Auth**: Bearer token
- **Message Format**: OpenAI-compatible
- **Specialties**: Cost-effective, strong reasoning (R1 model)

#### Mistral
- **Endpoint**: `https://api.mistral.ai/v1`
- **Auth**: Bearer token
- **Message Format**: OpenAI-compatible
- **Specialties**: European provider, strong code generation (Codestral)

#### Ollama
- **Endpoint**: `http://localhost:11434` (configurable)
- **Auth**: None (local)
- **Message Format**: OpenAI-compatible
- **Specialties**: Self-hosted, 100+ open-source models, no API costs

#### GPUStack
- **Endpoint**: Configurable (user-specified)
- **Auth**: API key
- **Message Format**: OpenAI-compatible
- **Specialties**: Self-hosted GPU clusters, horizontal scaling

#### OpenRouter
- **Endpoint**: `https://openrouter.ai/api/v1`
- **Auth**: Bearer token
- **Message Format**: OpenAI-compatible
- **Specialties**: Aggregator (100+ models), unified billing, fallback routing

#### Perplexity
- **Endpoint**: `https://api.perplexity.ai`
- **Auth**: Bearer token
- **Message Format**: OpenAI-compatible
- **Specialties**: Search-augmented responses, real-time information

#### xAI
- **Endpoint**: `https://api.x.ai/v1`
- **Auth**: Bearer token
- **Message Format**: OpenAI-compatible
- **Specialties**: Grok models, large context window (128K)

## Rails Integration Architecture

### acts_as_* Pattern

```
Rails Models                    RubyLLM Components
     │                                 │
     │ Include                         │
     ▼                                 ▼
┌─────────────┐              ┌──────────────┐
│Conversation │──has_many──►│ChatMessage   │
│ acts_as_chat│              │acts_as_message│
└─────────────┘              └──────────────┘
     │                                │
     │ Extends with                   │ Extends with
     ▼                                ▼
┌──────────────────────┐    ┌─────────────────────┐
│  ChatMethods         │    │  MessageMethods     │
│  - ask()             │    │  - to_message()     │
│  - stream()          │    │  - from_message()   │
│  - with_tool()       │    │  - tool_calls=()    │
│  - reload_messages() │    └─────────────────────┘
└──────────────────────┘
     │
     │ Creates/uses
     ▼
┌──────────────────┐
│ RubyLLM::Chat    │
│ (in-memory)      │
└──────────────────┘
```

### Database Schema

```sql
-- Conversations table
CREATE TABLE conversations (
  id BIGINT PRIMARY KEY,
  model_name VARCHAR(255) NOT NULL,
  system_prompt TEXT,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

-- Messages table
CREATE TABLE chat_messages (
  id BIGINT PRIMARY KEY,
  conversation_id BIGINT NOT NULL,
  role VARCHAR(50) NOT NULL,
  content TEXT,
  tool_calls JSON,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  
  FOREIGN KEY (conversation_id) REFERENCES conversations(id),
  INDEX idx_conversation_created (conversation_id, created_at)
);

-- Models table (optional, for DB-backed model registry)
CREATE TABLE llm_models (
  id BIGINT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  provider VARCHAR(100) NOT NULL,
  capabilities JSON,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  
  UNIQUE INDEX idx_name (name)
);
```

### Request Flow với Rails

```
HTTP Request
  │
  ▼
Controller
  │
  │ @conversation = Conversation.find(params[:id])
  │ @conversation.ask(params[:message])
  ▼
┌────────────────────────────────────────┐
│ Conversation (AR Model)                │
│   - acts_as_chat mixin                 │
│   - has_many :messages                 │
└───────────────┬────────────────────────┘
                │
                │ ChatMethods#ask
                ▼
┌────────────────────────────────────────┐
│ Create ChatMessage (user)              │
│   - conversation.messages.create!(     │
│       role: 'user',                    │
│       content: content                 │
│     )                                  │
└───────────────┬────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│ Initialize RubyLLM::Chat               │
│   - @chat = RubyLLM.chat(              │
│       model: conversation.model_name   │
│     )                                  │
│   - Load messages from DB              │
└───────────────┬────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│ Call @chat.ask(content)                │
│   - Sends to LLM provider              │
│   - Returns response                   │
└───────────────┬────────────────────────┘
                │
                ▼
┌────────────────────────────────────────┐
│ Create ChatMessage (assistant)         │
│   - conversation.messages.create!(     │
│       role: 'assistant',               │
│       content: response.text,          │
│       tool_calls: response.tool_calls  │
│     )                                  │
└───────────────┬────────────────────────┘
                │
                ▼
            Controller
         (render response)
```

## Concurrency & Performance

### Thread Safety

**Thread-Safe Components:**
- `Configuration` (singleton với mutex)
- `Models` registry (immutable after load)
- `Chat` instances (isolated state)
- Faraday connections (thread-safe)

**Not Thread-Safe:**
- Individual `Chat` instances (mutable state)
- ActiveRecord models (standard AR behavior)

### Async Operations

**Fiber-Based Streaming:**
```ruby
# Streaming uses fibers for efficient I/O
def stream(messages:, **options)
  Fiber.new do
    connection.post(endpoint) do |req|
      req.options.on_data = lambda do |chunk|
        Fiber.yield(parse_chunk(chunk))
      end
    end
  end.resume
end
```

### Connection Pooling

```ruby
# Faraday connections reused per provider instance
class Provider
  def connection
    @connection ||= Faraday.new(api_base) do |conn|
      # Connection configuration
    end
  end
end

# To improve: Add connection pool for concurrent requests
class Provider
  def connection
    @connection_pool ||= ConnectionPool.new(size: 5) do
      Faraday.new(api_base) { |conn| ... }
    end
  end
end
```

## Error Handling Architecture

### Exception Hierarchy

```
StandardError
  │
  └─► RubyLLM::Error
        ├─► ProviderError
        │     ├─► AuthenticationError (401)
        │     ├─► RateLimitError (429)
        │     │     └── @retry_after (seconds)
        │     ├─► ModelNotFoundError (404)
        │     └─► QuotaExceededError (403)
        │
        ├─► ConfigurationError
        │     ├─► MissingAPIKeyError
        │     └─► InvalidProviderError
        │
        └─► InvalidRequestError
              ├─► ToolExecutionError
              └─► InvalidModelError
```

### Error Propagation

```
Provider API Error
  │
  ▼
HTTP Response (4xx/5xx)
  │
  ▼
Faraday Middleware
  │
  ▼
Provider#handle_response
  │ (status code → exception class)
  ▼
Raise Specific Exception
  │
  ▼
Chat#ask catches & re-raises
  │
  ▼
User Code (rescue)
```

## Security Architecture

### API Key Management

```
Environment Variables
  │
  ▼
RubyLLM.configure
  │
  ▼
Configuration.instance
  │ (stored in memory)
  ▼
Provider reads on demand
  │
  ▼
Faraday Authorization header
  │ (never logged)
  ▼
HTTPS to Provider API
```

**Best Practices:**
- API keys stored in `Configuration` singleton
- Never logged (Faraday logger filters Authorization header)
- Transmitted only via HTTPS
- Not persisted to database or disk
- Validated before first use

### Input Sanitization

```ruby
# File upload validation
def validate_attachment(file_path)
  # 1. File exists
  raise InvalidRequestError unless File.exist?(file_path)
  
  # 2. File size limit
  raise InvalidRequestError if File.size(file_path) > 100.megabytes
  
  # 3. MIME type check
  mime_type = Marcel::MimeType.for(Pathname.new(file_path))
  raise InvalidRequestError unless allowed_mime_types.include?(mime_type)
  
  # 4. No path traversal
  raise InvalidRequestError if file_path.include?('..')
end
```

## Deployment Architecture

### Standalone Ruby App

```
Ruby Process
  ├─► require 'ruby_llm'
  ├─► RubyLLM.configure { ... }
  └─► chat = RubyLLM.chat(...)
      └─► HTTP → LLM Provider APIs
```

### Rails Application

```
Rails Server Process
  ├─► config/initializers/ruby_llm.rb
  │   └─► RubyLLM.configure { ... }
  ├─► Models: acts_as_chat, acts_as_message
  ├─► Controllers: conversation.ask(...)
  ├─► Jobs: Background LLM processing
  └─► HTTP → LLM Provider APIs
```

### Multi-Instance Deployment

```
Load Balancer
  │
  ├─► Rails Instance 1
  │   └─► RubyLLM → Provider APIs
  │
  ├─► Rails Instance 2
  │   └─► RubyLLM → Provider APIs
  │
  └─► Rails Instance N
      └─► RubyLLM → Provider APIs

Database (Shared)
  └─► conversations, chat_messages
```

**Considerations:**
- Each instance has own RubyLLM configuration
- No shared state between instances (except database)
- Faraday connections per-instance
- Model registry loaded per-instance (minimal memory impact)

## Testing Architecture

### VCR Cassettes

```
Test Execution
  │
  ▼
RSpec Example
  │
  │ provider.chat(...)
  ▼
┌──────────────────────────────────────┐
│ VCR Intercepts HTTP Request          │
│   - Match by: URI, method, body      │
└───────────────┬──────────────────────┘
                │
                ├─► Cassette exists?
                │   └─► Yes: Return recorded response
                │
                └─► No: Make real HTTP request
                    └─► Record response to cassette
```

**Cassette Structure:**
```yaml
# spec/fixtures/vcr_cassettes/openai/chat.yml
http_interactions:
- request:
    method: post
    uri: https://api.openai.com/v1/chat/completions
    body:
      encoding: UTF-8
      string: '{"model":"gpt-4o","messages":[...]}'
    headers:
      Authorization:
      - Bearer <OPENAI_API_KEY>  # Filtered by VCR
  response:
    status:
      code: 200
    body:
      encoding: UTF-8
      string: '{"id":"chatcmpl-123","object":"chat.completion",...}'
  recorded_at: Sat, 01 Feb 2026 12:00:00 GMT
```

### Test Matrix

```
CI Pipeline
  │
  ├─► Ruby 3.1.3
  │   ├─► Rails 7.1
  │   └─► Rails 8.1
  │
  ├─► Ruby 3.2
  │   ├─► Rails 7.1
  │   └─► Rails 8.1
  │
  ├─► Ruby 3.3
  │   ├─► Rails 7.1
  │   └─► Rails 8.1
  │
  ├─► Ruby 4.0 (head)
  │   └─► Rails 8.1
  │
  └─► JRuby 9.4
      └─► Rails 8.1
```

## Performance Characteristics

### Latency Sources

```
Total Request Time
  ├─► Ruby Overhead: 1-5ms
  │   ├─► Message formatting
  │   ├─► JSON encoding
  │   └─► Object instantiation
  │
  ├─► Network Latency: 20-100ms
  │   ├─► DNS lookup
  │   ├─► TCP handshake
  │   └─► TLS handshake
  │
  └─► Provider Processing: 500-5000ms
      ├─► Model inference
      └─► Response generation
```

**Typical Latencies:**
- Simple chat (gpt-4o-mini): 500-1500ms
- Complex chat với tools: 2000-5000ms
- Streaming (first token): 200-500ms
- Embeddings: 100-300ms
- Image generation: 5000-15000ms

### Memory Usage

```
RubyLLM Baseline: ~5MB
  ├─► Core classes: ~1MB
  ├─► Model registry: ~2MB
  └─► Provider implementations: ~2MB

Per Chat Instance: ~10KB
  ├─► Message history: ~1KB per message
  └─► Attachments: file size (base64 encoded)

Peak Memory (1000 concurrent chats):
  ~15MB baseline + ~10MB messages = ~25MB
```

## Extensibility Points

### Adding New Providers

```ruby
# 1. Create provider class
module RubyLLM
  module Providers
    class NewProvider < Provider
      def api_base
        'https://api.newprovider.com'
      end
      
      def chat(messages:, **options)
        # Implementation
      end
    end
  end
end

# 2. Register provider
RubyLLM.register_provider(:new_provider, Providers::NewProvider)

# 3. Add configuration
RubyLLM.configure do |config|
  config.new_provider_api_key = ENV['NEW_PROVIDER_KEY']
end

# 4. Add models to registry
# config/models.yml
new_provider:
  model-name:
    provider: new_provider
    capabilities: [chat, streaming]
```

### Custom Middleware

```ruby
RubyLLM.configure do |config|
  config.faraday_middleware = lambda do |conn|
    # Custom request logging
    conn.request :instrumentation, name: 'ruby_llm.request'
    
    # Custom retry logic
    conn.request :retry, max: 5, interval: 2
    
    # Custom response handling
    conn.response :custom_error_handler
    
    conn.adapter Faraday.default_adapter
  end
end
```

### Plugin System (Future)

```ruby
# Potential plugin architecture
RubyLLM.use_plugin(:caching) do |plugin|
  plugin.cache_store = Rails.cache
  plugin.ttl = 1.hour
end

RubyLLM.use_plugin(:monitoring) do |plugin|
  plugin.backend = :prometheus
  plugin.export_to = 'http://localhost:9091'
end
```

## Summary

RubyLLM's architecture prioritizes:

1. **Simplicity**: Minimal dependencies, clear abstractions
2. **Extensibility**: Easy to add providers, tools, features
3. **Performance**: Efficient streaming, connection reuse
4. **Reliability**: Comprehensive error handling, retries
5. **Flexibility**: Works standalone hoặc với Rails
6. **Developer Experience**: Intuitive API, excellent defaults

**Key Architectural Decisions:**
- Provider abstraction pattern cho unified interface
- Model registry cho capability detection
- Faraday cho HTTP với middleware support
- VCR cho deterministic testing
- ActiveRecord integration via mixins (optional)
- Fiber-based streaming cho memory efficiency
