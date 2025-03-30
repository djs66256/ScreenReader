import Foundation
import os.lock

public final class LLMManager {
    public static let shared = LLMManager()
    
    private var lock = os_unfair_lock()
    private var _allProviders: [LLMProviderConfig] = []
    private var _allModels: [LLMModel] = []
    private var _selectedProviderID: String?
    
    // MARK: - Public Properties
    
    public var selectedProviderID: String? {
        withLock { _selectedProviderID }
    }
    
    public var allProviders: [LLMProviderConfig] {
        withLock { _allProviders }
    }
    
    public var allModels: [LLMModel] {
        withLock { _allModels }
    }
    
    // MARK: - Initialization
    
    private init() {
        loadAndMergeData()
    }
    
    // MARK: - Data Loading
    
    private func loadAndMergeData() {
        let (userProviders, userModels) = loadUserData()
        let builtInProviders = LLMProviderConfig.loadProviders()
        let builtInModels = LLMModel.loadModels()
        
        withLock {
            _selectedProviderID = UserDefaults.standard.string(forKey: "selected_provider_id")
            _allProviders = mergeProviders(userProviders, builtInProviders)
            _allModels = mergeModels(userModels, builtInModels)
        }
    }
    
    private func loadUserData() -> ([LLMProviderConfig], [LLMModel]) {
        let decoder = JSONDecoder()
        let providers = decodeUserDefaultsData(forKey: "llm_providers", type: [LLMProviderConfig].self) ?? []
        let models = decodeUserDefaultsData(forKey: "llm_models", type: [LLMModel].self) ?? []
        return (providers, models)
    }
    
    // MARK: - Data Access
    
    public func provider(forID id: String) -> LLMProviderConfig? {
        withLock { _allProviders.first { $0.id == id } }
    }
    
    public func model(forID id: String) -> LLMModel? {
        withLock { _allModels.first { $0.id == id } }
    }
    
    public func models(forProviderID providerID: String) -> [LLMModel] {
        withLock {
            guard let provider = _allProviders.first(where: { $0.id == providerID }) else {
                return []
            }
            return _allModels.filter { provider.supportedModelIDs.contains($0.id) }
        }
    }
    
    // MARK: - Data Modification
    
    public func updateProvider(_ updatedProvider: LLMProviderConfig) {
        withLock {
            if let index = _allProviders.firstIndex(where: { $0.id == updatedProvider.id }) {
                _allProviders[index] = updatedProvider
                save()
            }
        }
    }
    
    public static let providerDidChange = Notification.Name("LLMProviderDidChange")
    
    public func setSelectedProvider(_ id: String?) {
        var shouldNotify = false
        withLock {
            let oldID = _selectedProviderID
            _selectedProviderID = id
            save()
            shouldNotify = oldID != id
        }
        
        if shouldNotify {
            NotificationCenter.default.post(name: Self.providerDidChange, object: nil)
        }
    }
    
    private func save() {
        withLock {
            do {
                try saveData(_allProviders, forKey: "llm_providers")
                try saveData(_allModels, forKey: "llm_models")
                UserDefaults.standard.set(_selectedProviderID, forKey: "selected_provider_id")
            } catch {
                os_log("保存失败: %@", type: .error, error.localizedDescription)
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func withLock<T>(_ block: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return try block()
    }
    
    private func decodeUserDefaultsData<T: Decodable>(forKey key: String, type: T.Type) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    
    private func saveData<T: Encodable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        UserDefaults.standard.set(data, forKey: key)
    }
    
    private func mergeProviders(_ user: [LLMProviderConfig], _ builtIn: [LLMProviderConfig]) -> [LLMProviderConfig] {
        let userIDs = Set(user.map(\.id))
        return user + builtIn.filter { !userIDs.contains($0.id) }
    }
    
    private func mergeModels(_ user: [LLMModel], _ builtIn: [LLMModel]) -> [LLMModel] {
        let userIDs = Set(user.map(\.id))
        return user + builtIn.filter { !userIDs.contains($0.id) }
    }
}
