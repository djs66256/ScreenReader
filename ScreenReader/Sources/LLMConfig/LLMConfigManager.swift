import Foundation

final class LLMConfigManager {
    static let shared = LLMConfigManager()
    
    // 配置repository
    let providerConfigRepository: any LLMProviderConfigRepository
    let modelConfigRepository: any LLMModelConfigRepository
    let ruleConfigRepository: any LLMRuleConfigRepository
    let agentConfigRepository: any AgentConfigRepository
    
    
    private init() {
        // 初始化基础repository
        providerConfigRepository = LLMProviderConfigActorRepository()
        modelConfigRepository = LLMModelConfigActorRepository()
        ruleConfigRepository = LLMRuleConfigActorRepository()
        
        // 修改：传入依赖的repository初始化agentConfigRepository
        agentConfigRepository = AgentConfigActorRepository(
            providerRepository: providerConfigRepository,
            ruleRepository: ruleConfigRepository
        )
    }
}