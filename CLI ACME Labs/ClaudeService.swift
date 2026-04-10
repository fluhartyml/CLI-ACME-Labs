//
//  ClaudeService.swift
//  CLI ACME Labs
//
//  Created by Michael Fluharty on 4/10/26.
//
//  Spawns Claude Code as a subprocess. CLI ACME Labs is the terminal,
//  Claude Code is the engine. Authentication uses the user's existing
//  Claude Code session — no API key needed.
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

@Observable
class ClaudeService {
    var messages: [ClaudeMessage] = []
    var isLoading = false
    var error: String?
    var isRunning = false

    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?

    /// Callback for conversation output (bottom pane)
    var onConversation: ((String) -> Void)?
    /// Callback for production output (top pane)
    var onProduction: ((String, String?) -> Void)?

    var isConfigured: Bool {
        resolveClaude() != nil
    }

    private func resolveClaude() -> String? {
        let paths = [
            "\(NSHomeDirectory())/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude"
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return findClaude()
    }

    private func findClaude() -> String? {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["claude"]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return path?.isEmpty == false ? path : nil
    }

    func start(workingDirectory: URL? = nil) {
        guard !isRunning else { return }

        guard let claudePath = resolveClaude() else {
            error = "Claude Code not found. Install it with: npm install -g @anthropic-ai/claude-code"
            return
        }

        process = Process()
        inputPipe = Pipe()
        outputPipe = Pipe()
        errorPipe = Pipe()

        process?.executableURL = URL(fileURLWithPath: claudePath)
        process?.arguments = ["--print"]  // Non-interactive mode, reads from stdin
        process?.standardInput = inputPipe
        process?.standardOutput = outputPipe
        process?.standardError = errorPipe

        if let dir = workingDirectory {
            process?.currentDirectoryURL = dir
        }

        // Read stdout asynchronously
        outputPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.handleOutput(output)
                }
            }
        }

        // Read stderr asynchronously
        errorPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.onConversation?(output)
                }
            }
        }

        process?.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.onConversation?("\nClaude Code process ended.\n")
            }
        }

        do {
            try process?.run()
            isRunning = true
        } catch {
            self.error = "Failed to start Claude Code: \(error.localizedDescription)"
        }
    }

    func send(_ message: String) {
        guard isRunning, let inputPipe else {
            // If not running, start a one-shot conversation
            sendOneShot(message)
            return
        }

        let userMsg = ClaudeMessage(role: "user", content: message)
        messages.append(userMsg)

        let data = (message + "\n").data(using: .utf8)!
        inputPipe.fileHandleForWriting.write(data)
    }

    /// One-shot mode: run claude with a single prompt and capture output
    private func sendOneShot(_ message: String) {
        let userMsg = ClaudeMessage(role: "user", content: message)
        messages.append(userMsg)
        isLoading = true

        Task.detached { [weak self] in
            let paths = [
                "\(NSHomeDirectory())/.local/bin/claude",
                "/opt/homebrew/bin/claude",
                "/usr/local/bin/claude"
            ]
            guard let claudePath = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
                await MainActor.run {
                    self?.error = "Claude Code not found."
                    self?.isLoading = false
                }
                return
            }

            let task = Process()
            let outPipe = Pipe()
            let errPipe = Pipe()

            task.executableURL = URL(fileURLWithPath: claudePath)
            task.arguments = ["--print", message]
            task.standardOutput = outPipe
            task.standardError = errPipe

            do {
                try task.run()
                task.waitUntilExit()

                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outData, encoding: .utf8) ?? ""

                let assistantMsg = ClaudeMessage(role: "assistant", content: output)

                await MainActor.run {
                    self?.messages.append(assistantMsg)
                    self?.isLoading = false
                    self?.handleOutput(output)
                }
            } catch {
                await MainActor.run {
                    self?.error = error.localizedDescription
                    self?.isLoading = false
                }
            }
        }
    }

    private func handleOutput(_ output: String) {
        // Route output to appropriate pane
        // Look for production markers or code fences
        if output.contains("<<<PRODUCTION") || output.contains("```") {
            // Has production content — parse it
            let parsed = parseResponse(output)
            onConversation?(parsed.conversation)
            if let production = parsed.production {
                onProduction?(production, parsed.productionTitle)
            }
        } else {
            // All conversation
            onConversation?(output)
        }
    }

    func parseResponse(_ response: String) -> (conversation: String, production: String?, productionTitle: String?) {
        // Check for code fences
        guard let fenceStart = response.range(of: "```"),
              let fenceEnd = response.range(of: "```",
                                            range: fenceStart.upperBound..<response.endIndex) else {
            return (conversation: response, production: nil, productionTitle: nil)
        }

        let afterFence = fenceStart.upperBound
        let firstNewline = response[afterFence...].firstIndex(of: "\n") ?? fenceEnd.lowerBound
        let title = String(response[afterFence..<firstNewline]).trimmingCharacters(in: .whitespaces)
        let codeContent = String(response[response.index(after: firstNewline)..<fenceEnd.lowerBound])

        var conversation = response
        let fullFenceRange = fenceStart.lowerBound..<fenceEnd.upperBound
        conversation.removeSubrange(fullFenceRange)
        conversation = conversation.trimmingCharacters(in: .whitespacesAndNewlines)

        if codeContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (conversation: response, production: nil, productionTitle: nil)
        }

        return (
            conversation: conversation.isEmpty ? "Done." : conversation,
            production: codeContent,
            productionTitle: title.isEmpty ? "Output" : title
        )
    }

    func stop() {
        process?.terminate()
        inputPipe?.fileHandleForWriting.closeFile()
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        isRunning = false
    }

    func clearHistory() {
        messages.removeAll()
    }
}
