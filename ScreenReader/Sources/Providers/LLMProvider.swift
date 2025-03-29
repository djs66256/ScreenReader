import Foundation

protocol LLMProvider {
    /// 发送消息序列并获取响应流
    func send(messages: [Message]) async throws -> AsyncThrowingStream<Message, Error>
    
    /// 当前使用的模型名称
    var modelName: String { get }
}

enum LLMProviderFactory {
    static func createProvider(config: LLMProviderConfig, model: LLMModel) throws -> LLMProvider {
        do {
            if config.id.lowercased().contains("openai") {
                return OpenAIProvider(config: config, model: model)
            }
            throw NSError(domain: "LLMProviderFactory", code: 400, userInfo: [NSLocalizedDescriptionKey: "Unsupported provider type"])
        } catch {
            return defaultProvider
        }
    }

    static var defaultProvider: LLMProvider {
        let defaultConfig = LLMProviderConfig(
            id: "default-openai",
            name: "Default OpenAI",
            apiKey: nil,
            defaultBaseURL: "https://api.openai.com/v1",
            supportedModelIDs: ["gpt-3.5-turbo"]
        )
        let defaultModel = LLMModel(
            id: "gpt-3.5-turbo",
            name: "GPT-3.5 Turbo",
            capabilities: [.chat],
            maxTokens: 4096,
            defaultTemperature: 0.7,
            thinkToken: nil
        )
        return OpenAIProvider(config: defaultConfig, model: defaultModel)
    }
}

