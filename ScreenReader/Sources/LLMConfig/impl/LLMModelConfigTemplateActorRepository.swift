import Foundation

actor LLMModelConfigTemplateActorRepository: LLMModelConfigTemplateRepository {
    private let templateFileURL: URL
    
    init() {
        templateFileURL = StoragePath.Models.templates
    }
    
    func getAllModelTemplates() async -> [LLMModelConfigTemplate] {
        guard let data = try? Data(contentsOf: templateFileURL) else { return [] }
        return (try? JSONDecoder().decode([LLMModelConfigTemplate].self, from: data)) ?? []
    }
}