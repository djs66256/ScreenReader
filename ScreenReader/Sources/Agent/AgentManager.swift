import Foundation

class AgentManager {
    private var agents: [UUID: Agent] = [:]
    private(set) var activeAgentID: UUID?
    
    func createAgent(provider: LLMProvider) -> Agent {
        let agent = Agent(provider: provider)
        agents[agent.id] = agent
        activeAgentID = agent.id
        return agent
    }
    
    func getActiveAgent() -> Agent? {
        guard let id = activeAgentID else { return nil }
        return agents[id]
    }
    
    func switchToAgent(_ id: UUID) throws {
        guard agents[id] != nil else {
            throw AgentError.agentNotFound
        }
        activeAgentID = id
    }
    
    func removeAgent(_ id: UUID) {
        agents.removeValue(forKey: id)
        if activeAgentID == id {
            activeAgentID = nil
        }
    }
}
