import Foundation
import Alamofire
import os

class AnthropicProvider: LLMProvider {
    private let config: ChatModeConfig
    
    private var apiKey: String? {
        config.provider?.apiKey
    }

    var modelName: String? {
        config.model?.modelName
    }

    var baseURLString: String? {
        config.provider?.defaultBaseURL
    }

    init(config: ChatModeConfig) {
        self.config = config
    }
    
    func send(messages: [Message]) async throws -> AsyncThrowingStream<Message, Error> {
        guard let apiKey = apiKey else {
            throw NSError(domain: "AnthropicProvider", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key is not configured"])
        }
        guard let modelName = modelName else {
            throw NSError(domain: "AnthropicProvider", code: 400, userInfo: [NSLocalizedDescriptionKey: "Model name is not configured"])
        }
        guard let baseURL = URL(string: baseURLString ?? "") else {
            throw NSError(domain: "AnthropicProvider", code: 400, userInfo: [NSLocalizedDescriptionKey: "API URL is not configured"])
        }
        
        let url = baseURL.appendingPathComponent("v1/messages")
        
        let headers = [
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
            "Content-Type": "application/json"
        ]

        struct AnthropicURLRequest: URLRequestConvertible {
            let url: URL
            let headers: [String: String]
            let messages: [Message]
            let modelName: String
            
            func asURLRequest() throws -> URLRequest {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.allHTTPHeaderFields = headers
                
                let parameters: [String: Any] = [
                    "model": modelName,
                    "messages": messages.map { $0.toAnthropicFormat() },
                    "max_tokens": 4096,
                    "stream": true
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
                return request
            }
        }

        let request = AnthropicURLRequest(
            url: url,
            headers: headers,
            messages: messages,
            modelName: modelName
        )

        return AsyncThrowingStream { continuation in
            let textLock = OSAllocatedUnfairLock()
            var text = ""
            let dataRequest = AF.streamRequest(
                request,
                automaticallyCancelOnStreamError: true
            )
            .responseStream { stream in
                switch stream.event {
                case let .stream(result):
                    switch result {
                    case let .success(data):
                        do {
                            let lines = String(decoding: data, as: UTF8.self)
                                .components(separatedBy: "\n")
                                .filter { $0.hasPrefix("data:") && $0 != "data: [DONE]" }
                            
                            for line in lines {
                                let jsonString = line.replacingOccurrences(of: "data: ", with: "")
                                if let jsonData = jsonString.data(using: .utf8),
                                   let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                                   let delta = json["delta"] as? [String: Any],
                                   let content = delta["text"] as? String {
                                    
                                    let message = textLock.withLock {
                                        text += content
                                        return Message(
                                            role: .assistant,
                                            text: text
                                        )
                                    }
                                    continuation.yield(message)
                                }
                            }
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    case let .failure(error):
                        continuation.finish(throwing: error)
                    }
                case let .complete(completion):
                    if let error = completion.error {
                        continuation.finish(throwing: error)
                    } else {
                        continuation.finish()
                    }
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                dataRequest.cancel()
            }
        }
    }
}

/*
import anthropic
import base64
import httpx

# Option 1: Base64-encoded image
image_url = "https://upload.wikimedia.org/wikipedia/commons/a/a7/Camponotus_flavomarginatus_ant.jpg"
image_media_type = "image/jpeg"
image_data = base64.standard_b64encode(httpx.get(image_url).content).decode("utf-8")

message = anthropic.Anthropic().messages.create(
    model="claude-3-7-sonnet-20250219",
    max_tokens=1024,
    messages=[
        {
            "role": "user",
            "content": [
                {
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": image_media_type,
                        "data": image_data,
                    },
                },
                {
                    "type": "text",
                    "text": "What is in the above image?"
                }
            ],
        }
    ],
)
print(message)

# Option 2: URL-referenced image
message_from_url = anthropic.Anthropic().messages.create(
    model="claude-3-7-sonnet-20250219",
    max_tokens=1024,
    messages=[
        {
            "role": "user",
            "content": [
                {
                    "type": "image",
                    "source": {
                        "type": "url",
                        "url": "https://upload.wikimedia.org/wikipedia/commons/a/a7/Camponotus_flavomarginatus_ant.jpg",
                    },
                },
                {
                    "type": "text",
                    "text": "What is in the above image?"
                }
            ],
        }
    ],
)
print(message_from_url)
*/
extension Message {
    func toAnthropicFormat() -> [String: Any] {
        var contentArray = [[String: Any]]()
        
        switch self.content {
        case .singleText(let text):
            contentArray.append([
                "type": "text",
                "text": text
            ])
        case .multiModal(let parts):
            for part in parts {
                switch part.type {
                case .text:
                    contentArray.append([
                        "type": "text",
                        "text": part.value
                    ])
                case .imageURL:
                    contentArray.append([
                        "type": "image",
                        "source": [
                            "type": "url",
                            "url": part.value
                        ]
                    ])
                case .imageData:
                    let components = part.value.components(separatedBy: ";base64,")
                    if components.count == 2 {
                        contentArray.append([
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": components[0].replacingOccurrences(of: "data:", with: ""),
                                "data": components[1]
                            ]
                        ])
                    }
                }
            }
        }
        
        return [
            "role": self.role == .assistant ? "assistant" : "user",
            "content": contentArray
        ]
    }
}