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

/// Parsed response split into conversation and production content
struct ParsedResponse {
    let conversation: String  // Goes to bottom pane (talking to the human)
    let production: String?   // Goes to top pane (file edits, diffs, builds, tool output)
    let productionTitle: String?
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

    func send(_ userMessage: String) async -> ParsedResponse? {
        guard let apiKey, !apiKey.isEmpty else {
            error = "No API key configured. Use /login to set your key."
            return nil
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

            isLoading = false
            return parseResponse(responseText)
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return nil
        }
    }

    /// Parse Claude's response into conversation (bottom pane) and production (top pane)
    ///
    /// Production blocks are marked with:
    ///   <<<PRODUCTION title="filename.swift">>>
    ///   ... content ...
    ///   <<<END_PRODUCTION>>>
    ///
    /// Everything outside production blocks is conversation.
    func parseResponse(_ response: String) -> ParsedResponse {
        let productionPattern = "<<<PRODUCTION(?:\\s+title=\"([^\"]*)\")?>\\>\\>\\n([\\s\\S]*?)<<<END_PRODUCTION>>>"

        guard let regex = try? NSRegularExpression(pattern: productionPattern, options: []) else {
            return ParsedResponse(conversation: response, production: nil, productionTitle: nil)
        }

        let range = NSRange(response.startIndex..., in: response)
        let matches = regex.matches(in: response, options: [], range: range)

        if matches.isEmpty {
            // No production blocks — check for code fences as fallback
            return parseCodeFences(response)
        }

        var conversation = response
        var productionContent = ""
        var productionTitle: String?

        // Extract production blocks (process in reverse to preserve indices)
        for match in matches.reversed() {
            // Get title if present
            if match.numberOfRanges > 1,
               let titleRange = Range(match.range(at: 1), in: response) {
                productionTitle = String(response[titleRange])
            }

            // Get content
            if match.numberOfRanges > 2,
               let contentRange = Range(match.range(at: 2), in: response) {
                productionContent = String(response[contentRange])
            }

            // Remove production block from conversation
            if let fullRange = Range(match.range, in: conversation) {
                conversation.removeSubrange(fullRange)
            }
        }

        conversation = conversation.trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedResponse(
            conversation: conversation.isEmpty ? "Done." : conversation,
            production: productionContent.isEmpty ? nil : productionContent,
            productionTitle: productionTitle
        )
    }

    /// Fallback: parse markdown code fences as production output
    private func parseCodeFences(_ response: String) -> ParsedResponse {
        guard let fenceStart = response.range(of: "```"),
              let fenceEnd = response.range(of: "```",
                                            range: fenceStart.upperBound..<response.endIndex) else {
            return ParsedResponse(conversation: response, production: nil, productionTitle: nil)
        }

        let afterFence = fenceStart.upperBound
        let firstNewline = response[afterFence...].firstIndex(of: "\n") ?? fenceEnd.lowerBound
        let title = String(response[afterFence..<firstNewline]).trimmingCharacters(in: .whitespaces)
        let codeContent = String(response[response.index(after: firstNewline)..<fenceEnd.lowerBound])

        // Remove the code fence from conversation text
        var conversation = response
        let fullFenceRange = fenceStart.lowerBound..<fenceEnd.upperBound
        conversation.removeSubrange(fullFenceRange)
        conversation = conversation.trimmingCharacters(in: .whitespacesAndNewlines)

        if codeContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ParsedResponse(conversation: response, production: nil, productionTitle: nil)
        }

        return ParsedResponse(
            conversation: conversation.isEmpty ? "File updated." : conversation,
            production: codeContent,
            productionTitle: title.isEmpty ? "Output" : title
        )
    }

    func clearHistory() {
        messages.removeAll()
    }
}
