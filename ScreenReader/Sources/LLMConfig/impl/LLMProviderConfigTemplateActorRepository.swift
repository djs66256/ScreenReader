import Foundation

actor LLMProviderConfigTemplateActorRepository: LLMProviderConfigTemplateRepository {
    private let templateFileURL: URL
    
    init() {
        templateFileURL = StoragePath.Providers.templates
    }
    
    func getAllConfigTemplates() async -> [LLMProviderConfigTemplate] {
        guard let data = try? Data(contentsOf: templateFileURL) else { return [] }
        return (try? JSONDecoder().decode([LLMProviderConfigTemplate].self, from: data)) ?? []
    }
}