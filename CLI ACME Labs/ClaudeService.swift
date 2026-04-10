//
//  ClaudeService.swift
//  CLI ACME Labs
//
//  Created by Michael Fluharty on 4/10/26.
//

import Foundation

struct ClaudeMessage: Codable, Identifiable {
    let id: UUID
    let role: String
    let content: String
    let timestamp: Date

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = .now
    }
}

struct AnthropicRequest: Codable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [MessagePayload]

    struct MessagePayload: Codable {
        let role: String
        let content: String
    }
}

struct AnthropicResponse: Codable {
    let id: String
    let content: [ContentBlock]
    let stop_reason: String?

    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }
}

@Observable
class ClaudeService {
    var messages: [ClaudeMessage] = []
    var isLoading = false
    var error: String?

    private var apiKey: String?
    private let model = "claude-sonnet-4-6"
    private var systemPrompt = ""

    func configure(apiKey: String, systemPrompt: String = "") {
        self.apiKey = apiKey
        self.systemPrompt = systemPrompt
    }

    var isConfigured: Bool {
        apiKey != nil && !apiKey!.isEmpty
    }

    func send(_ userMessage: String) async {
        guard let apiKey, !apiKey.isEmpty else {
            error = "No API key configured. Use /login to set your key."
            return
        }

        let userMsg = ClaudeMessage(role: "user", content: userMessage)
        messages.append(userMsg)
        isLoading = true
        error = nil

        let messagePayloads = messages.map {
            AnthropicRequest.MessagePayload(role: $0.role, content: $0.content)
        }

        let request = AnthropicRequest(
            model: model,
            max_tokens: 8192,
            system: systemPrompt,
            messages: messagePayloads
        )

        do {
            var urlRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
            urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            urlRequest.httpBody = try JSONEncoder().encode(request)

            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if httpResponse.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "ClaudeService",
                              code: httpResponse.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "API error \(httpResponse.statusCode): \(errorBody)"])
            }

            let anthropicResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            let responseText = anthropicResponse.content
                .compactMap { $0.text }
                .joined()

            let assistantMsg = ClaudeMessage(role: "assistant", content: responseText)
            messages.append(assistantMsg)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func clearHistory() {
        messages.removeAll()
    }
}
