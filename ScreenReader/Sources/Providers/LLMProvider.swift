import Foundation

protocol LLMProvider {
    /// 发送消息序列并获取响应流
    func send(messages: [Message]) async throws -> AsyncThrowingStream<Message, Error>
    
    /// 获取模型支持的最大上下文长度
//    var maxContextLength: Int { get }
    
    /// 当前使用的模型名称
//    var modelName: String { get }
    
    /// 计算消息序列的token数量
//    func countTokens(_ messages: [Message]) throws -> Int
}

extension LLMProvider {
    /// 便捷方法：发送单条消息
    func send(_ message: Message) async throws -> AsyncThrowingStream<Message, Error> {
        try await send(messages: [message])
    }
}
