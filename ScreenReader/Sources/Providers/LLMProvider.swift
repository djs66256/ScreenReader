import Foundation

protocol LLMProvider {
    /// 发送消息序列并获取响应流
    func send(messages: [Message]) async throws -> AsyncThrowingStream<Message, Error>
    
}

enum LLMProviderType: String, Codable {
    case openai = "openai"
    case anthropic = "anthropic"
    case ollama = "ollama"
    case openaiCompatible = "openai-compatible"
}

enum LLMProviderFactory {
    static func createProvider(config: ChatModeConfig) throws -> LLMProvider {
        guard let provider = config.provider else {
            return defaultProvider
        }
        
        guard let type = LLMProviderType(rawValue: provider.type.lowercased()) else {
            throw NSError(domain: "LLMProviderFactory", code: 400, userInfo: [NSLocalizedDescriptionKey: "Unsupported provider type"])
        }
        
        switch type {
        case .openai:
            return OpenAIProvider(config: config)
        case .anthropic:
            return AnthropicProvider(config: config)
        case .ollama:
            return OllamaProvider(config: config)
        case .openaiCompatible:
            return OpenAICompatibleProvider(config: config)
        }
    }
    
    static var allSupportedProviderTypes: [LLMProviderType] {
        return [.openai, .anthropic, .ollama, .openaiCompatible]
    }

    static var defaultProvider: LLMProvider {
        let defaultConfig = ChatModeConfig(
            id: "default",
            name: "Default",
            provider: LLMProviderConfig(
                id: "ollama",
                type: "ollama",
                name: "Ollama",
                defaultBaseURL: "http://localhost:11434",
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


