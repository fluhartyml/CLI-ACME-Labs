//
//  TerminalView.swift
//  CLI ACME Labs
//
//  Created by Michael Fluharty on 4/10/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct TerminalView: View {
    @State var claude = ClaudeService()
    @State var memory = MemoryManager()
    @State var inputText = ""
    @State var showingFolderPicker = false
    @State var showingLoginPrompt = false
    @State var showingWakeUpConfirm = false
    @State var showingSafeExitConfirm = false
    @State var teletypeText = "CLI ACME Labs v1.0\nType /login to authenticate, /setup to choose your developer folder.\n\n"

    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Top bar — Wake Up / Safe Exit
            HStack {
                Button("Wake Up") {
                    showingWakeUpConfirm = true
                }
                .buttonStyle(.bordered)
                .confirmationDialog("Wake Up?", isPresented: $showingWakeUpConfirm) {
                    Button("Yes") { runWakeUp() }
                    Button("Oops", role: .cancel) {}
                }

                Spacer()

                Text("CLI ACME Labs")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)

                Spacer()

                Button("Safe Exit") {
                    showingSafeExitConfirm = true
                }
                .buttonStyle(.bordered)
                .confirmationDialog("Safe Exit?", isPresented: $showingSafeExitConfirm) {
                    Button("Yes") { runSafeExit() }
                    Button("Oops", role: .cancel) {}
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.black)

            Divider().background(Color.green.opacity(0.5))

            // Teletype pane — scrolling output
            ScrollViewReader { proxy in
                ScrollView {
                    Text(teletypeText)
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id("teletypeBottom")
                }
                .background(Color.black)
                .onChange(of: teletypeText) {
                    withAnimation {
                        proxy.scrollTo("teletypeBottom", anchor: .bottom)
                    }
                }
            }

            Divider().background(Color.green.opacity(0.5))

            // Terminal pane — interactive input
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    if claude.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Claude is thinking...")
                                .font(.system(size: 18, design: .monospaced))
                                .foregroundStyle(.green.opacity(0.6))
                        }
                        .padding()
                    }

                    if let error = claude.error {
                        Text("Error: \(error)")
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(.red)
                            .padding()
                    }
                }
                .frame(maxHeight: .infinity)
                .background(Color.black)

                HStack(spacing: 4) {
                    Text(">")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)

                    TextField("", text: $inputText)
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundStyle(.green)
                        .textFieldStyle(.plain)
                        .focused($inputFocused)
                        .onSubmit {
                            handleInput()
                        }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.black)
            }
            .background(Color.black)
        }
        .background(Color.black)
        .onAppear {
            inputFocused = true
            memory.loadFromBookmark()
            if let key = KeychainHelper.load() {
                claude.configure(apiKey: key, systemPrompt: buildSystemPrompt())
            }
        }
        .sheet(isPresented: $showingLoginPrompt) {
            LoginView(onSave: { key in
                KeychainHelper.save(apiKey: key)
                claude.configure(apiKey: key, systemPrompt: buildSystemPrompt())
                appendTeletype("Authenticated. API key saved to Keychain.\n")
                showingLoginPrompt = false
            })
        }
        .fileImporter(isPresented: $showingFolderPicker,
                      allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                memory.saveBookmark(for: url)
                memory.configure(developerFolder: url)
                appendTeletype("Developer folder set: \(url.path)\nclaude.Memory structure created.\n")
            }
        }
    }

    private func handleInput() {
        let input = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        inputText = ""

        // Echo input to teletype
        appendTeletype("> \(input)\n")

        // Handle commands
        if input.hasPrefix("/") {
            handleCommand(input)
            return
        }

        // Send to Claude
        guard claude.isConfigured else {
            appendTeletype("Not authenticated. Type /login first.\n")
            return
        }

        Task {
            await claude.send(input)
            if let lastMessage = claude.messages.last, lastMessage.role == "assistant" {
                appendTeletype("\nClaude:\n\(lastMessage.content)\n\n")
            }
            if let error = claude.error {
                appendTeletype("Error: \(error)\n")
            }
        }
    }

    private func handleCommand(_ command: String) {
        switch command.lowercased() {
        case "/login":
            showingLoginPrompt = true
        case "/setup":
            showingFolderPicker = true
        case "/status":
            let authStatus = claude.isConfigured ? "Authenticated" : "Not authenticated"
            let memStatus = memory.isConfigured ? "Configured (\(memory.rootPath?.path ?? ""))" : "Not configured"
            appendTeletype("Auth: \(authStatus)\nMemory: \(memStatus)\n")
        case "/clear":
            teletypeText = ""
        case "/help":
            appendTeletype("""
            Commands:
              /login    — Set your Anthropic API key
              /setup    — Choose your developer folder
              /status   — Show auth and memory status
              /clear    — Clear the teletype
              /help     — Show this help
            \n
            """)
        default:
            appendTeletype("Unknown command: \(command)\nType /help for available commands.\n")
        }
    }

    private func appendTeletype(_ text: String) {
        teletypeText += text
    }

    private func buildSystemPrompt() -> String {
        var prompt = "You are Claude, running inside CLI ACME Labs — a terminal-style interface. "
        prompt += "You have persistent memory stored in the user's developer folder. "
        prompt += "Be direct, concise, and helpful. Use plain language."

        // Load memory context if available
        if let chatHistory = memory.chatHistoryPath,
           let content = memory.readFile(chatHistory) {
            prompt += "\n\nRecent chat history:\n\(content)"
        }

        return prompt
    }

    private func runWakeUp() {
        guard memory.isConfigured else {
            appendTeletype("Memory not configured. Run /setup first.\n")
            return
        }
        appendTeletype("--- Wake-Up Routine ---\n")

        // Read hello-claude
        if let path = memory.helloClaudePath, let _ = memory.readFile(path) {
            appendTeletype("Read hello-claude.md\n")
        }

        // Read MORNING-NOTES
        if let path = memory.morningNotesPath, let notes = memory.readFile(path) {
            appendTeletype("MORNING-NOTES:\n\(notes)\n\n")
        } else {
            appendTeletype("No MORNING-NOTES.md found.\n")
        }

        // Read Chat-History
        if let path = memory.chatHistoryPath, let _ = memory.readFile(path) {
            appendTeletype("Chat-History loaded.\n")
        }

        appendTeletype("Wake-up complete. Ready to work.\n\n")

        // Send context to Claude
        if claude.isConfigured {
            claude.configure(apiKey: KeychainHelper.load() ?? "", systemPrompt: buildSystemPrompt())
        }
    }

    private func runSafeExit() {
        appendTeletype("--- Safe Exit Routine ---\n")

        if memory.isConfigured {
            // Save transcript
            if let sessionFolder = memory.currentSessionFolder() {
                memory.saveTranscript(claude.messages, to: sessionFolder)
                appendTeletype("Transcript saved to \(sessionFolder.lastPathComponent)/\n")
            }

            // Update Chat-History
            if let chatPath = memory.chatHistoryPath {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy MMM dd HHmm"
                let entry = "\n### [\(formatter.string(from: .now))] Session ended\n- \(claude.messages.count) messages exchanged\n"
                if var existing = memory.readFile(chatPath) {
                    existing += entry
                    memory.writeFile(chatPath, content: existing)
                }
                appendTeletype("Chat-History updated.\n")
            }

            appendTeletype("Session saved. Safe to close.\n")
        } else {
            appendTeletype("Memory not configured — session not saved.\n")
        }
    }
}
