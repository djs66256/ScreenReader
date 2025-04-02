import Foundation

enum StoragePath {
    // MARK: - 基础目录
    private static let appSupportBaseDirectory: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ScreenReader")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()
    
    public static let templatesBaseDirectory: URL = {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources")
    }()
    
    // MARK: - 配置目录
    static let configsDirectory: URL = {
        let directory = appSupportBaseDirectory
            .appendingPathComponent("Configs")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()
    
    // MARK: - 具体文件路径
    enum Providers {
        static let templates = templatesBaseDirectory
            .appendingPathComponent("ProviderTemplates.json")
        
        static func configFile(id: String) -> URL {
            configsDirectory
                .appendingPathComponent("Providers")
                .appendingPathComponent("\(id).json")
        }
    }
    
    enum Models {
        static let templates = templatesBaseDirectory
            .appendingPathComponent("ModelTemplates.json")
        
        static func configFile(modelName: String) -> URL {
            configsDirectory
                .appendingPathComponent("Models")
                .appendingPathComponent("\(modelName).json")
        }
    }
    
    enum Rules {
        static let templates = templatesBaseDirectory
            .appendingPathComponent("RuleTemplates.json")
        
        static func configFile(id: String) -> URL {
            configsDirectory
                .appendingPathComponent("Rules")
                .appendingPathComponent("\(id).json")
        }
    }
    
    enum Agents {
        static let templates = templatesBaseDirectory
            .appendingPathComponent("AgentTemplates.json")
        
        static func configFile(id: String) -> URL {
            configsDirectory
                .appendingPathComponent("Agents")
                .appendingPathComponent("\(id).json")
        }
    }
}
