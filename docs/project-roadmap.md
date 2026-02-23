# RubyLLM - Project Roadmap

## Phiên Bản Hiện Tại

**Version 1.11.0** - Stable release với đầy đủ tính năng core.

## Lịch Sử Phát Triển

### v1.11.0 (Current)
- Model registry improvements
- Enhanced provider support
- Bug fixes và stability improvements

### v1.10.x
- Extended thinking support
- Thinking token tracking
- Migration generator: `ruby_llm:upgrade_to_v1_10`

### v1.9.x
- Cached tokens support
- Raw content handling
- Migration generator: `ruby_llm:upgrade_to_v1_9`

### v1.7.x
- New Rails-like API
- Model references improvements
- Migration generator: `ruby_llm:upgrade_to_v1_7`

## Tính Năng Đã Hoàn Thành

### Core Features
- [x] Unified Chat API
- [x] Multi-provider support (13 providers)
- [x] Streaming responses
- [x] Tool/Function calling
- [x] Structured output (JSON Schema)
- [x] Multimodal support (images, video, audio, documents)
- [x] Embeddings generation
- [x] Image generation
- [x] Content moderation
- [x] Audio transcription

### Provider Support
- [x] OpenAI (full support)
- [x] Anthropic Claude
- [x] Google Gemini
- [x] Google VertexAI
- [x] AWS Bedrock
- [x] Azure OpenAI
- [x] DeepSeek
- [x] Mistral
- [x] Ollama (local)
- [x] GPUStack (local)
- [x] OpenRouter
- [x] Perplexity
- [x] xAI

### Rails Integration
- [x] `acts_as_chat` pattern
- [x] `acts_as_message` pattern
- [x] `acts_as_tool_call` pattern
- [x] `acts_as_model` pattern
- [x] Install generator
- [x] Chat UI generator
- [x] Upgrade generators
- [x] Turbo streaming support

### Advanced Features
- [x] Model registry với 800+ models
- [x] Capability detection
- [x] Pricing information
- [x] Extended thinking support
- [x] Fiber-based async

## Hướng Phát Triển

### Maintained (Actively Supported)

Các tính năng được maintain và sẽ tiếp tục cải thiện:

1. **Provider Updates**
   - Cập nhật API changes từ providers
   - Thêm models mới vào registry
   - Fix compatibility issues

2. **Bug Fixes**
   - Critical bugs
   - Security vulnerabilities
   - Compatibility issues

3. **Documentation**
   - API documentation
   - Usage examples
   - Migration guides

### Potential Improvements

Các cải tiến có thể được xem xét (cần discussion):

1. **Performance**
   - Connection pooling improvements
   - Caching strategies
   - Memory optimization

2. **Testing**
   - Improved VCR cassette management
   - Better test isolation
   - Performance benchmarks

3. **Developer Experience**
   - Better error messages
   - Enhanced logging
   - Debugging tools

## Scope Guidelines

### In Scope (Sẽ được xem xét)

Theo CONTRIBUTING.md, RubyLLM tập trung vào:

- Core LLM communication
- Provider integrations
- Streaming support
- Cost/token tracking
- Basic persistence (Rails integration)

### Out of Scope (Sẽ bị từ chối)

Các tính năng sau **không thuộc** scope của RubyLLM:

- Multi-agent orchestration
- RAG pipelines
- Prompt management systems
- Vector database integrations
- Testing frameworks
- Anything implementable trong 5-10 lines application code

Những tính năng này nên được implement trong application code hoặc separate gems.

## Contribution Guidelines

### Submitting Features

1. **Mở Issue trước** - Không submit PR cho new features mà không có approved issue
2. **Discuss scope** - Đảm bảo feature thuộc scope của RubyLLM
3. **Keep PRs focused** - Không quá lớn, có thể review được
4. **Write tests** - Mọi feature cần có tests

### Submitting Bug Fixes

1. Check existing issues
2. Verify đây là bug của RubyLLM (không phải application code)
3. Provide reproduction steps
4. Submit PR với fix

### Provider Contributions

- **Core providers**: High acceptance bar
- **New/small providers**: Prefer community gem approach

## Release Schedule

RubyLLM không có fixed release schedule. Releases được tạo khi:

- Critical bugs được fix
- Security vulnerabilities được patch
- Significant features hoàn thành
- Provider API changes cần update

## Support

### Getting Help

1. **Documentation**: https://rubyllm.com
2. **GitHub Issues**: Bug reports và feature requests
3. **Community**: Ruby/Rails community channels

### Response Times

Theo CONTRIBUTING.md:

> This is my gift to the Ruby community. Gifts don't come with SLAs.

Maintainers respond khi có thể. Không có guaranteed response time.

### Sponsorship

Sponsorship tại https://github.com/sponsors/crmne là cách để nói cảm ơn, không mua priority support.

## Liên Kết

- [Project Overview](./project-overview-pdr.md)
- [Code Standards](./code-standards.md)
- [System Architecture](./system-architecture.md)
- [Deployment Guide](./deployment-guide.md)
- [CONTRIBUTING.md](../CONTRIBUTING.md)
