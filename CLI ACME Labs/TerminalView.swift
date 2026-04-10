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
    @State var isShuttingDown = false  // Safe Exit state: waiting for tomorrow's plans

    // Top pane — production output (documents, files, previews)
    @State var productionText = ""
    @State var productionTitle = "Production"
    @State var productionLineCount = 0
    @State var previousProductionText = ""

    // Middle pane — pinned reference (roadmap, notes, etc.)
    @State var pinnedText = ""
    @State var pinnedTitle = ""
    @State var showPinnedPane = false

    // Bottom pane — full conversation (like Claude Code terminal)
    @State var conversationText = "CLI ACME Labs v1.0\nType /setup to choose your workspace folder, then /login to authenticate.\n\n"

    @FocusState private var inputFocused: Bool
    @State var showCommandPicker = false
    @State var selectedCommandIndex = 0

    private let commands: [(name: String, description: String)] = [
        ("/login", "Set your Anthropic API key"),
        ("/setup", "Choose your workspace folder"),
        ("/status", "Show auth and memory status"),
        ("/view", "Display a file in production pane"),
        ("/pin", "Pin a file to the reference pane"),
        ("/unpin", "Close the reference pane"),
        ("/clear", "Clear all panes"),
        ("/clear production", "Clear production pane only"),
        ("/help", "Show all commands"),
    ]

    private var filteredCommands: [(name: String, description: String)] {
        if inputText == "/" {
            return commands
        }
        let query = inputText.lowercased()
        return commands.filter { $0.name.lowercased().hasPrefix(query) }
    }

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

            // Top pane — Pinned reference (roadmap, notes, etc.)
            if showPinnedPane {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(pinnedTitle)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan.opacity(0.6))
                        Spacer()
                        Button(action: { unpinPane() }) {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.cyan.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.1))

                    ScrollView([.vertical, .horizontal]) {
                        Text(pinnedText)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(.cyan)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .background(Color.black)
                }

                Divider().background(Color.cyan.opacity(0.5))
            }

            // Middle pane — Production view (document/file editor with line numbers)
            VStack(alignment: .leading, spacing: 0) {
                // Production pane title bar
                HStack {
                    Text(productionTitle)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.6))
                    Spacer()
                    if productionLineCount > 0 {
                        Text("\(productionLineCount) lines")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.4))
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))

                if productionText.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32))
                            .foregroundStyle(.green.opacity(0.2))
                        Text("Production output will appear here.")
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(.green.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                } else {
                    ProductionPaneView(text: productionText,
                                      previousText: previousProductionText)
                }
            }

            Divider().background(Color.green.opacity(0.5))

            // Bottom pane — Interactive conversation (like Claude Code)
            VStack(alignment: .leading, spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(conversationText)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(.green)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .id("conversationBottom")

                        if claude.isLoading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Claude is thinking...")
                                    .font(.system(size: 18, design: .monospaced))
                                    .foregroundStyle(.green.opacity(0.6))
                            }
                            .padding(.horizontal)
                        }
                    }
                    .background(Color.black)
                    .onChange(of: conversationText) {
                        withAnimation {
                            proxy.scrollTo("conversationBottom", anchor: .bottom)
                        }
                    }
                }

                // Command picker popup
                if showCommandPicker && !filteredCommands.isEmpty {
                    CommandPickerView(commands: filteredCommands,
                                     selectedIndex: selectedCommandIndex)
                }

                HStack(spacing: 4) {
                    Text(">")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)

                    TextField("", text: $inputText)
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundStyle(.green)
                        .textFieldStyle(.plain)
                        .focused($inputFocused)
                        .onChange(of: inputText) {
                            if inputText.hasPrefix("/") && !inputText.contains(" ") {
                                showCommandPicker = true
                                selectedCommandIndex = 0
                            } else {
                                showCommandPicker = false
                            }
                        }
                        .onSubmit {
                            if showCommandPicker && !filteredCommands.isEmpty {
                                inputText = filteredCommands[selectedCommandIndex].name
                                showCommandPicker = false
                                // Add space for commands that take arguments
                                if ["/view", "/pin"].contains(inputText) {
                                    inputText += " "
                                } else {
                                    handleInput()
                                }
                            } else {
                                handleInput()
                            }
                        }
                        #if os(macOS)
                        .onKeyPress(.upArrow) {
                            if showCommandPicker {
                                selectedCommandIndex = max(0, selectedCommandIndex - 1)
                                return .handled
                            }
                            return .ignored
                        }
                        .onKeyPress(.downArrow) {
                            if showCommandPicker {
                                selectedCommandIndex = min(filteredCommands.count - 1, selectedCommandIndex + 1)
                                return .handled
                            }
                            return .ignored
                        }
                        .onKeyPress(.escape) {
                            if showCommandPicker {
                                showCommandPicker = false
                                inputText = ""
                                return .handled
                            }
                            return .ignored
                        }
                        #endif
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
                appendConversation("Claude: Authenticated. API key saved to Keychain.\n\n")
                showingLoginPrompt = false
            })
        }
        .fileImporter(isPresented: $showingFolderPicker,
                      allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                memory.saveBookmark(for: url)
                memory.configure(developerFolder: url)
                appendConversation("Claude: Developer folder set: \(url.path)\nclaude.Memory structure created.\n\n")
            }
        }
    }

    // MARK: - Input Handling

    private func handleInput() {
        let input = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        inputText = ""

        // Echo input to conversation
        appendConversation("You: \(input)\n\n")

        // If shutting down, this input is tomorrow's plans
        if isShuttingDown {
            completeSafeExit(tomorrowsPlans: input)
            return
        }

        // Handle commands
        if input.hasPrefix("/") {
            handleCommand(input)
            return
        }

        // Send to Claude
        guard claude.isConfigured else {
            appendConversation("Claude: Not authenticated. Type /login first.\n\n")
            return
        }

        Task {
            if let parsed = await claude.send(input) {
                // Conversation goes to bottom pane
                appendConversation("Claude: \(parsed.conversation)\n\n")

                // Production goes to top pane
                if let production = parsed.production {
                    productionTitle = parsed.productionTitle ?? "Output"
                    setProduction(production)
                }
            }
            if let error = claude.error {
                appendConversation("Error: \(error)\n\n")
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
            appendConversation("Auth: \(authStatus)\nMemory: \(memStatus)\n\n")
        case "/clear":
            setProduction("")
            productionTitle = "Production"
            conversationText = ""
        case "/clear production":
            setProduction("")
            productionTitle = "Production"
        case "/unpin":
            unpinPane()
        case "/help":
            appendConversation("""
            Commands:
              /login             — Set your Anthropic API key
              /setup             — Choose your developer folder
              /status            — Show auth and memory status
              /clear             — Clear all panes
              /clear production  — Clear production pane only
              /view <file>       — Display a file in the production pane
              /pin <file>        — Pin a file to the middle reference pane
              /unpin             — Close the middle pane
              /help              — Show this help
            \n
            """)
        default:
            if command.lowercased().hasPrefix("/view ") {
                let filename = String(command.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                viewFile(filename)
            } else if command.lowercased().hasPrefix("/pin ") {
                let filename = String(command.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                pinFile(filename)
            } else {
                appendConversation("Unknown command: \(command)\nType /help for available commands.\n\n")
            }
        }
    }

    // MARK: - Production Pane

    /// Display a file from the memory structure in the production pane
    private func viewFile(_ filename: String) {
        guard memory.isConfigured else {
            appendConversation("Memory not configured. Run /setup first.\n\n")
            return
        }
        guard let memoryPath = memory.memoryBasePath?.deletingLastPathComponent() else { return }

        let filePath = memoryPath.appendingPathComponent(filename)
        if let content = memory.readFile(filePath) {
            productionTitle = filename
            setProduction(content)
            appendConversation("Displaying \(filename) in production pane.\n\n")
        } else {
            appendConversation("File not found: \(filename)\n\n")
        }
    }

    // MARK: - Pinned Pane

    private func pinFile(_ filename: String) {
        guard memory.isConfigured else {
            appendConversation("Memory not configured. Run /setup first.\n\n")
            return
        }
        guard let memoryPath = memory.memoryBasePath?.deletingLastPathComponent() else { return }

        let filePath = memoryPath.appendingPathComponent(filename)
        if let content = memory.readFile(filePath) {
            pinnedTitle = filename
            pinnedText = content
            showPinnedPane = true
            appendConversation("Pinned \(filename) to reference pane.\n\n")
        } else {
            appendConversation("File not found: \(filename)\n\n")
        }
    }

    private func unpinPane() {
        showPinnedPane = false
        pinnedText = ""
        pinnedTitle = ""
        appendConversation("Reference pane closed.\n\n")
    }

    // MARK: - Output

    /// Conversation pane — bottom
    private func appendConversation(_ text: String) {
        conversationText += text
    }

    /// Set production pane — saves previous for diff, then replaces
    private func setProduction(_ text: String) {
        previousProductionText = productionText
        productionText = text
        productionLineCount = text.components(separatedBy: "\n").count
    }

    // MARK: - System Prompt

    private func buildSystemPrompt() -> String {
        var prompt = """
        You are Claude, running inside CLI ACME Labs — a terminal-style interface with two panes.

        BOTTOM PANE (conversation): Everything you say to the human appears here. Questions, answers, \
        discussion, confirmations, status updates. This is your voice talking to them.

        TOP PANE (production): When you produce a file, document, chapter, code, diff, or build output, \
        wrap it in production tags:

        <<<PRODUCTION title="filename.swift">>>
        ... file content here ...
        <<<END_PRODUCTION>>>

        The production pane has line numbers. The human will reference line numbers when requesting edits \
        (e.g. "line 42 is wrong, change it to X"). When you edit, produce the updated file and the production \
        pane will show a diff with green additions and red removals.

        Alternatively, code fences (```filename) also route to the production pane.

        RULES:
        - Conversation text goes to the bottom pane. Never wrap conversation in production tags.
        - File content, documents, code, and structured output go to the top pane via production tags.
        - Be direct, concise, and helpful. Use plain language.
        - You have persistent memory stored in the user's developer folder.
        """

        if let chatHistory = memory.chatHistoryPath,
           let content = memory.readFile(chatHistory) {
            prompt += "\n\nRecent chat history:\n\(content)"
        }

        return prompt
    }

    // MARK: - Routines

    private func runWakeUp() {
        guard memory.isConfigured else {
            appendConversation("Claude: Memory not configured. Run /setup first.\n\n")
            return
        }
        appendConversation("--- Wake-Up Routine ---\n")

        if let path = memory.helloClaudePath, let _ = memory.readFile(path) {
            appendConversation("Read hello-claude.md\n")
        }

        if let path = memory.morningNotesPath, let notes = memory.readFile(path) {
            productionTitle = "MORNING-NOTES.md"
            setProduction(notes)
            appendConversation("MORNING-NOTES displayed in production pane.\n")
        } else {
            appendConversation("No MORNING-NOTES.md found.\n")
        }

        if let path = memory.chatHistoryPath, let _ = memory.readFile(path) {
            appendConversation("Chat-History loaded.\n")
        }

        appendConversation("Wake-up complete. Ready to work.\n\n")

        if claude.isConfigured {
            claude.configure(apiKey: KeychainHelper.load() ?? "", systemPrompt: buildSystemPrompt())
        }
    }

    private func runSafeExit() {
        guard memory.isConfigured else {
            appendConversation("Claude: Memory not configured — session not saved.\n\n")
            return
        }

        appendConversation("--- Safe Exit Routine ---\n\n")
        appendConversation("Claude: What are your plans for tomorrow?\n\n")
        isShuttingDown = true
    }

    private func completeSafeExit(tomorrowsPlans: String) {
        isShuttingDown = false

        // Save transcript to session folder
        if let sessionFolder = memory.currentSessionFolder() {
            memory.saveTranscript(claude.messages, to: sessionFolder)
            appendConversation("Transcript saved to \(sessionFolder.lastPathComponent)/\n")
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
            appendConversation("Chat-History updated.\n")
        }

        // Write MORNING-NOTES with tomorrow's plans
        if let morningPath = memory.morningNotesPath {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy MMM dd (EEEE)"
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
            let dateString = formatter.string(from: tomorrow)

            var notes = "# Morning Notes — \(dateString)\n\n"
            notes += "## Plans for Today\n\n"
            notes += tomorrowsPlans + "\n\n"

            // Add active session summary
            notes += "## Previous Session Summary\n\n"
            notes += "- \(claude.messages.count) messages exchanged\n"

            let sessionFormatter = DateFormatter()
            sessionFormatter.dateFormat = "yyyy MMM dd HHmm"
            notes += "- Session ended: \(sessionFormatter.string(from: .now))\n"

            memory.writeFile(morningPath, content: notes)
            appendConversation("MORNING-NOTES written for tomorrow.\n")

            // Show the notes in production pane
            productionTitle = "MORNING-NOTES.md"
            setProduction(notes)
        }

        appendConversation("\nSession saved. Safe to close.\n\n")
    }
}
