import Foundation

struct SessionConfig {
    let systemPrompt: String
    let maxContextLength: Int
    
    init(systemPrompt: String = "You are a helpful AI assistant", maxContextLength: Int = 4096) {
        self.systemPrompt = systemPrompt
        self.maxContextLength = maxContextLength
    }
}

actor ChatSession {
    let id: UUID
    let createdAt: Date
    private(set) var messages: [Message]
    private let provider: LLMProvider
    private let config: SessionConfig
    
    init(provider: LLMProvider, config: SessionConfig? = nil) {
        self.id = UUID()
        self.createdAt = Date()
        self.messages = []
        self.provider = provider
        self.config = config ?? SessionConfig()
        
        // 直接添加系统提示
        messages.append(Message(role: .system, text: self.config.systemPrompt))
    }
    
    func send(message userMessage: Message) async throws -> AsyncThrowingStream<Message, Error> {
        messages.append(userMessage)
        try validateContextLength()
        
        let responseStream = try await provider.send(messages: messages)
        
        return AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self else { return }
                
                // 在actor上下文中执行
                await self.handleResponseStream(
                    responseStream: responseStream,
                    continuation: continuation
                )
            }
        }
    }
    
    private func handleResponseStream(
        responseStream: AsyncThrowingStream<Message, Error>,
        continuation: AsyncThrowingStream<Message, Error>.Continuation
    ) async {
        var isFirstChunk = true
        var responseIndex: Int?
        
        do {
            for try await chunk in responseStream {
                if isFirstChunk {
                    // 第一个chunk时添加消息
                    messages.append(chunk)
                    responseIndex = messages.count - 1
                    isFirstChunk = false
                } else if let index = responseIndex {
                    // 后续chunk更新消息
                    messages[index] = chunk
                }
                continuation.yield(chunk)
            }
            continuation.finish()
        } catch {
            // 出错时移除不完整的响应
            if let index = responseIndex {
                messages.remove(at: index)
            }
            continuation.finish(throwing: error)
        }
    }
    
    func clear() {
        messages.removeAll()
    }

    private func validateContextLength() throws {
        // 验证逻辑保持不变
    }
}

enum SessionError: Error {
    case contextExceeded(max: Int, current: Int)
}
