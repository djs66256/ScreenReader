import Foundation

protocol LLMProvider {
    /// 发送消息序列并获取响应流
    func send(messages: [Message]) async throws -> AsyncThrowingStream<Message, Error>
    
}

enum LLMProviderFactory {
    static func createProvider(config: ChatModeConfig) throws -> LLMProvider {
        guard let provider = config.provider else {
            return defaultProvider
        }
        
        switch provider.id.lowercased() {
        case let id where id.contains("openai"):
            return OpenAIProvider(config: config)
        case let id where id.contains("anthropic"):
            return AnthropicProvider(config: config)
        case let id where id.contains("ollama"):
            return OllamaProvider(config: config)
        case let id where id.contains("openai-compatible"):  // 新增兼容类型判断
            return OpenAICompatibleProvider(config: config)
        default:
            throw NSError(domain: "LLMProviderFactory", code: 400, userInfo: [NSLocalizedDescriptionKey: "Unsupported provider type"])
        }
    }
    
    /// 获取所有支持的提供者类型ID
    static var allSupportedProviderIDs: [String] {
        return [
            "openai",
            "anthropic", 
            "ollama",
            "openai-compatible"
        ]
    }

    static var defaultProvider: LLMProvider {
        let defaultConfig = ChatModeConfig(
            id: "default",
            name: "Default",
            provider: LLMProviderConfig(
                id: "ollama",
                name: "Ollama",
                defaultBaseURL: "http://ollama.qingke.ai",
                apiKey: "ollama",
                supportedModelIDs: ["qwen2.5-coder:7b", "qwq:32b"]
            ),
            model: LLMModelConfig(
                modelName: "qwq:32b",
                systemPrompt: nil,
                maxTokens: 6400,
                temperature: 0.7,
                topP: 1.0,
                presencePenalty: 0.0,
                frequencyPenalty: 0.0,
                stopWords: []
            ),
            rules: []
        )
        return OpenAIProvider(config: defaultConfig)
    }
}

