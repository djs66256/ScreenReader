import Foundation

final class LLMConfigManager {
    static let shared = LLMConfigManager()
    
    // 配置repository
    let providerConfigRepository: any LLMProviderConfigRepository
    let modelConfigRepository: any LLMModelConfigRepository
    let rulerConfigRepository: any LLMRulerConfigRepository
    let chatModeConfigRepository: any ChatModeConfigRepository
    
    // 模板repository
    let providerTemplateRepository: any LLMProviderConfigTemplateRepository
    let modelTemplateRepository: any LLMModelConfigTemplateRepository
    
    private init() {
        // 初始化所有repository
        providerConfigRepository = LLMProviderConfigActorRepository()
        modelConfigRepository = LLMModelConfigActorRepository()
        rulerConfigRepository = LLMRulerConfigActorRepository()
        chatModeConfigRepository = ChatModeConfigActorRepository()
        
        providerTemplateRepository = LLMProviderConfigTemplateActorRepository()
        modelTemplateRepository = LLMModelConfigTemplateActorRepository()
    }
}