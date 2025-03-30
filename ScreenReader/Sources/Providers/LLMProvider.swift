import Foundation

protocol LLMProvider {
    /// 发送消息序列并获取响应流
    func send(messages: [Message]) async throws -> AsyncThrowingStream<Message, Error>
    
}

enum LLMProviderFactory {
    static func createProvider(config: ChatModeConfig) throws -> LLMProvider {
        do {
            if let provider = config.provider, provider.id.lowercased().contains("openai") {
                return OpenAIProvider(config: config)
            }
            throw NSError(domain: "LLMProviderFactory", code: 400, userInfo: [NSLocalizedDescriptionKey: "Unsupported provider type"])
        } catch {
            return defaultProvider
        }
    }

    static var defaultProvider: LLMProvider {
        let defaultConfig = ChatModeConfig(
            id: "default",
            name: "Default",
            provider: LLMProviderConfig(
                id: "ollama",
                name: "Ollama",
                defaultBaseURL: "http://ollama.qingke.ai/v1/chat/completions",
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

