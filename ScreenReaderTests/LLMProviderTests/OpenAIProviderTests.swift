import XCTest
@testable import ScreenReader

class OpenAIProviderTests: XCTestCase {
    
    var provider: OpenAIProvider!
    var mockConfig: LLMProviderConfig!
    var mockModel: LLMModel!
    
    override func setUp() {
        super.setUp()
        mockConfig = LLMProviderConfig(
            id: "openai-test",
            name: "OpenAI Test",
            apiKey: "test-api-key",
            defaultBaseURL: "http://ollama.qingke.ai/v1/chat/completions",
            supportedModelIDs: ["qwq:32b"]
        )
        mockModel = LLMModel(
            id: "qwq:32b",
            name: "qwq:32b",
            capabilities: [.chat],
            maxTokens: 6400,
            defaultTemperature: 0.7
        )
        provider = OpenAIProvider(config: mockConfig, model: mockModel)
    }
    
    override func tearDown() {
        provider = nil
        mockConfig = nil
        mockModel = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertEqual(provider.modelName, "qwq:32b")
    }
    
    func testUnsupportedModelInitialization() {
        let unsupportedModel = LLMModel(
            id: "unsupported-model",
            name: "Unsupported",
            capabilities: [],
            maxTokens: 6400,
            defaultTemperature: 0.7
        )
        XCTAssertThrowsError(try OpenAIProvider(config: mockConfig, model: unsupportedModel)) { error in
            XCTAssertEqual(error.localizedDescription, "Unsupported model ID: unsupported-model")
        }
    }
    
    func testSendMessage() async {
        let expectation = XCTestExpectation(description: "Send message completion")
        
        let messages = [
            Message(role:.system, text: "You are a helpful assistant."),
            Message(role: .user, text: "Hello")
        ]
        
        do {
            let stream = try await provider.send(messages: messages)
            
            var receivedMessage: Message?
            for try await message in stream {
                print(message.content)
                receivedMessage = message
            }
            
            XCTAssertNotNil(receivedMessage)
            expectation.fulfill()
        } catch {
            XCTFail("Failed to send message: \(error)")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
