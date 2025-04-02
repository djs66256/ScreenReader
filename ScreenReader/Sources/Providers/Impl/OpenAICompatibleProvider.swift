import Foundation

class OpenAICompatibleProvider: LLMProvider {
    private let provider: OpenAIProvider

    init(config: AgentConfig) {
        self.provider = OpenAIProvider(config: config, isCompatibleMode: true)
    }
    
    func send(messages: [Message]) async throws -> AsyncThrowingStream<Message, Error> {
        return try await provider.send(messages: messages)
    }
}