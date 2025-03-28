import Foundation

class Agent {
    var id: UUID = UUID()
    private var provider: LLMProvider
    private var sessions: [UUID: ChatSession] = [:]
    private(set) var activeSessionID: UUID?
    
    init(provider: LLMProvider) {
        self.provider = provider
    }
    
    // 创建并激活新会话
    func createSession(config: SessionConfig? = nil) -> ChatSession {
        let session = ChatSession(provider: provider, config: config)
        sessions[session.id] = session
        activeSessionID = session.id
        return session
    }
    
    // 获取当前活跃会话
    func getActiveSession() -> ChatSession? {
        guard let id = activeSessionID else { return nil }
        return sessions[id]
    }
    
    // 切换会话
    func switchToSession(_ id: UUID) throws {
        guard sessions[id] != nil else {
            throw AgentError.sessionNotFound
        }
        activeSessionID = id
    }
    
    // 结束会话
    func endSession(_ id: UUID) {
        sessions.removeValue(forKey: id)
        if activeSessionID == id {
            activeSessionID = nil
        }
    }
}

// 扩展错误类型
enum AgentError: Error {
    case sessionNotFound
    case noActiveSession
    case agentNotFound
}
