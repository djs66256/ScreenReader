import Foundation

public struct LLMProviderSecureStorage {
    private enum Keys {
        static let providers = "screen_reader_providers"
        static let currentProvider = "screen_reader_current_provider"
    }
    
    // MARK: - 当前提供商
    public static var currentProvider: String? {
        get { KeychainConfig.get(key: Keys.currentProvider) }
        set {
            if let value = newValue {
                _ = KeychainConfig.save(key: Keys.currentProvider, value: value)
            } else {
                _ = KeychainConfig.delete(key: Keys.currentProvider)
            }
        }
    }
    
    // MARK: - 所有提供商配置
    private static var allProviders: [String: ProviderConfig] {
        get {
            guard let data = KeychainConfig.get(key: Keys.providers)?.data(using: .utf8),
                  let providers = try? JSONDecoder().decode([String: ProviderConfig].self, from: data) else {
                return [:]
            }
            return providers
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                _ = KeychainConfig.save(key: Keys.providers, value: String(data: data, encoding: .utf8) ?? "")
            } else {
                _ = KeychainConfig.delete(key: Keys.providers)
            }
        }
    }
    
    // MARK: - 当前配置
    public static var currentConfig: ProviderConfig? {
        guard let current = currentProvider else { return nil }
        return allProviders[current]
    }
    
    // MARK: - 操作单个提供商
    public static func saveProvider(_ name: String, config: ProviderConfig) {
        var providers = allProviders
        providers[name] = config
        allProviders = providers
    }
    
    public static func removeProvider(_ name: String) {
        var providers = allProviders
        providers.removeValue(forKey: name)
        allProviders = providers
    }
    
    public static func getProvider(_ name: String) -> ProviderConfig? {
        return allProviders[name]
    }
    
    // MARK: - 清除所有
    public static func clearAll() {
        _ = KeychainConfig.delete(key: Keys.providers)
        _ = KeychainConfig.delete(key: Keys.currentProvider)
    }
}

public struct ProviderConfig: Codable {
    public var apiKey: String
    public var baseUrl: String
    
    public init(apiKey: String, baseUrl: String) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl
    }
}