import XCTest
@testable import ScreenReader

final class LLMConfigTests: XCTestCase {
    
    var configManager: LLMConfigManager!
    
    override func setUp() {
        super.setUp()
        configManager = LLMConfigManager.shared
    }
    
    override func tearDown() {
        super.tearDown()
        // 清理测试数据
        Task {
            await clearTestData()
        }
    }
    
    // MARK: - LLMConfigManager Tests
    
    func testConfigManagerSingleton() {
        let manager1 = LLMConfigManager.shared
        let manager2 = LLMConfigManager.shared
        XCTAssertTrue(manager1 === manager2, "LLMConfigManager should be a singleton")
    }
    
    func testConfigManagerRepositoriesInitialized() {
        XCTAssertNotNil(configManager.providerConfigRepository)
        XCTAssertNotNil(configManager.modelConfigRepository)
        XCTAssertNotNil(configManager.rulerConfigRepository)
        XCTAssertNotNil(configManager.chatModeConfigRepository)
        XCTAssertNotNil(configManager.providerTemplateRepository)
        XCTAssertNotNil(configManager.modelTemplateRepository)
    }
    
    // MARK: - Provider Config Tests
    
    func testProviderConfigCRUD() async {
        // Create
        let template = LLMProviderConfigTemplate(id: "test_provider", name: "Test Provider", defaultBaseURL: "http://test.com")
        let config = LLMProviderConfig(template: template, apiKey: "test_key")
        let createdConfig = await configManager.providerConfigRepository.createConfig(config: config)
        XCTAssertEqual(createdConfig.id, "test_provider")
        
        // Read
        let fetchedConfig = await configManager.providerConfigRepository.getConfig(id: "test_provider")
        XCTAssertNotNil(fetchedConfig)
        XCTAssertEqual(fetchedConfig?.apiKey, "test_key")
        
        // Update
        var updatedConfig = config
        updatedConfig.apiKey = "updated_key"
        let updateResult = await configManager.providerConfigRepository.updateConfig(config: updatedConfig)
        XCTAssertTrue(updateResult)
        
        // Delete
        await configManager.providerConfigRepository.deleteConfig(id: "test_provider")
        let deletedConfig = await configManager.providerConfigRepository.getConfig(id: "test_provider")
        XCTAssertNil(deletedConfig)
    }
    
    // MARK: - Model Config Tests
    
    func testModelConfigCRUD() async {
        // Create
        let config = LLMModelConfig(
            modelName: "test_model",
            systemPrompt: "Test prompt",
            maxTokens: 100,
            temperature: 0.7,
            topP: 0.9,
            presencePenalty: 0.0,
            frequencyPenalty: 0.0,
            stopWords: []
        )
        let createdConfig = await configManager.modelConfigRepository.createConfig(config: config)
        XCTAssertEqual(createdConfig.modelName, "test_model")
        
        // Read
        let fetchedConfig = await configManager.modelConfigRepository.getConfig(modelName: "test_model")
        XCTAssertNotNil(fetchedConfig)
        XCTAssertEqual(fetchedConfig?.systemPrompt, "Test prompt")
        
        // Update
        var updatedConfig = config
        updatedConfig.systemPrompt = "Updated prompt"
        let updateResult = await configManager.modelConfigRepository.updateConfig(config: updatedConfig)
        XCTAssertTrue(updateResult)
        
        // Delete
        await configManager.modelConfigRepository.deleteConfig(modelName: "test_model")
        let deletedConfig = await configManager.modelConfigRepository.getConfig(modelName: "test_model")
        XCTAssertNil(deletedConfig)
    }
    
    // MARK: - Template Tests
    
    func testProviderTemplateLoading() async {
        let templates = await configManager.providerTemplateRepository.getAllConfigTemplates()
        XCTAssertFalse(templates.isEmpty, "Should load provider templates")
    }
    
    func testModelTemplateLoading() async {
        let templates = await configManager.modelTemplateRepository.getAllModelTemplates()
        XCTAssertFalse(templates.isEmpty, "Should load model templates")
    }
    
    // MARK: - Helper Methods
    
    private func clearTestData() async {
        await configManager.providerConfigRepository.deleteConfig(id: "test_provider")
        await configManager.modelConfigRepository.deleteConfig(modelName: "test_model")
    }
}