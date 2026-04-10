//
//  TerminalView.swift
//  CLI ACME Labs
//
//  Created by Michael Fluharty on 4/10/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct TerminalView: View {
    @State var terminal = TerminalEmulator()
    @State var memory = MemoryManager()
    @State var fileWatcher = FileWatcher()
    @State var inputText = ""
    @State var showingFolderPicker = false
    @State var showingWakeUpConfirm = false
    @State var showingSafeExitConfirm = false
    @State var isShuttingDown = false

    // Top pane — production output (driven by productpane.md)
    @State var productionText = ""
    @State var productionTitle = "Production"
    @State var productionLineCount = 0
    @State var previousProductionText = ""

    // Middle pane — pinned reference (driven by pinnedpane.md)
    @State var pinnedText = ""
    @State var pinnedTitle = ""
    @State var showPinnedPane = false

    @FocusState private var inputFocused: Bool
    @State var showCommandPicker = false
    @State var selectedCommandIndex = 0

    private let commands: [(name: String, description: String)] = [
        ("/setup", "Choose your developer folder"),
        ("/status", "Show connection and memory status"),
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

            // Bottom pane — Real terminal (zsh)
            VStack(alignment: .leading, spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(terminal.output)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(.green)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .id("terminalBottom")
                    }
                    .background(Color.black)
                    .onChange(of: terminal.output) {
                        withAnimation {
                            proxy.scrollTo("terminalBottom", anchor: .bottom)
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
            startFileWatchers()
            terminal.start()
        }
        .fileImporter(isPresented: $showingFolderPicker,
                      allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                memory.saveBookmark(for: url)
                memory.configure(developerFolder: url)
                startFileWatchers()
                appendTerminal("Claude: Developer folder set: \(url.path)\nclaude.Memory structure created.\n\n")
            }
        }
    }

    // MARK: - Input Handling

    private func handleInput() {
        let input = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        inputText = ""

        // If shutting down, this input is tomorrow's plans
        if isShuttingDown {
            completeSafeExit(tomorrowsPlans: input)
            return
        }

        // Handle ACME Labs commands
        if input.hasPrefix("/") {
            handleCommand(input)
            return
        }

        // Send to the shell (zsh, claude, ssh, whatever is running)
        terminal.sendLine(input)
    }

    private func handleCommand(_ command: String) {
        switch command.lowercased() {
        case "/setup":
            showingFolderPicker = true
        case "/status":
            let shellStatus = terminal.isRunning ? "Shell running" : "Shell not running"
            let memStatus = memory.isConfigured ? "Configured (\(memory.rootPath?.path ?? ""))" : "Not configured"
            terminal.output += "Status:\n  Shell: \(shellStatus)\n  Memory: \(memStatus)\n\n"
        case "/clear":
            setProduction("")
            productionTitle = "Production"
            terminal.clear()
        case "/clear production":
            setProduction("")
            productionTitle = "Production"
        case "/unpin":
            unpinPane()
        case "/help":
            appendTerminal("""
            Commands:
              /setup             — Choose your developer folder
              /status            — Show connection and memory status
              /clear             — Clear all panes
              /clear production  — Clear production pane only
              /view <file>       — Display a file in the production pane
              /pin <file>        — Pin a file to the reference pane
              /unpin             — Close the reference pane
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
                appendTerminal("Unknown command: \(command)\nType /help for available commands.\n\n")
            }
        }
    }

    // MARK: - Production Pane

    /// Display a file from the memory structure in the production pane
    private func viewFile(_ filename: String) {
        guard memory.isConfigured else {
            appendTerminal("Memory not configured. Run /setup first.\n\n")
            return
        }
        guard let memoryPath = memory.memoryBasePath?.deletingLastPathComponent() else { return }

        let filePath = memoryPath.appendingPathComponent(filename)
        if let content = memory.readFile(filePath) {
            productionTitle = filename
            setProduction(content)
            appendTerminal("Displaying \(filename) in production pane.\n\n")
        } else {
            appendTerminal("File not found: \(filename)\n\n")
        }
    }

    // MARK: - Pinned Pane

    private func pinFile(_ filename: String) {
        guard memory.isConfigured else {
            appendTerminal("Memory not configured. Run /setup first.\n\n")
            return
        }
        guard let memoryPath = memory.memoryBasePath?.deletingLastPathComponent() else { return }

        let filePath = memoryPath.appendingPathComponent(filename)
        if let content = memory.readFile(filePath) {
            pinnedTitle = filename
            pinnedText = content
            showPinnedPane = true
            appendTerminal("Pinned \(filename) to reference pane.\n\n")
        } else {
            appendTerminal("File not found: \(filename)\n\n")
        }
    }

    private func unpinPane() {
        showPinnedPane = false
        pinnedText = ""
        pinnedTitle = ""
        appendTerminal("Reference pane closed.\n\n")
    }

    // MARK: - Output

    /// Terminal output — bottom pane
    private func appendTerminal(_ text: String) {
        terminal.output += text
    }

    /// Set production pane — saves previous for diff, then replaces
    private func setProduction(_ text: String) {
        previousProductionText = productionText
        productionText = text
        productionLineCount = text.components(separatedBy: "\n").count
    }

    // MARK: - File Watchers

    private func startFileWatchers() {
        guard memory.isConfigured else { return }

        // Watch productpane.md — drives the production pane
        if let productPath = memory.productPanePath {
            fileWatcher.watch(productPath) { content in
                productionTitle = "productpane.md"
                setProduction(content)
            }
        }

        // Watch pinnedpane.md — drives the pinned reference pane
        if let pinnedPath = memory.pinnedPanePath {
            fileWatcher.watch(pinnedPath) { content in
                if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    showPinnedPane = false
                } else {
                    pinnedTitle = "pinnedpane.md"
                    pinnedText = content
                    showPinnedPane = true
                }
            }
        }
    }

    // MARK: - Routines

    private func runWakeUp() {
        guard memory.isConfigured else {
            appendTerminal("Claude: Memory not configured. Run /setup first.\n\n")
            return
        }
        appendTerminal("--- Wake-Up Routine ---\n")

        if let path = memory.helloClaudePath, let _ = memory.readFile(path) {
            appendTerminal("Read hello-claude.md\n")
        }

        if let path = memory.morningNotesPath, let notes = memory.readFile(path) {
            productionTitle = "MORNING-NOTES.md"
            setProduction(notes)
            appendTerminal("MORNING-NOTES displayed in production pane.\n")
        } else {
            appendTerminal("No MORNING-NOTES.md found.\n")
        }

        if let path = memory.chatHistoryPath, let _ = memory.readFile(path) {
            appendTerminal("Chat-History loaded.\n")
        }

        appendTerminal("Wake-up complete. Ready to work.\n\n")
    }

    private func runSafeExit() {
        guard memory.isConfigured else {
            appendTerminal("Claude: Memory not configured — session not saved.\n\n")
            return
        }

        appendTerminal("--- Safe Exit Routine ---\n\n")
        appendTerminal("Claude: What are your plans for tomorrow?\n\n")
        isShuttingDown = true
    }

    private func completeSafeExit(tomorrowsPlans: String) {
        isShuttingDown = false

        // Save terminal output as transcript
        if let sessionFolder = memory.currentSessionFolder() {
            let transcriptURL = sessionFolder.appendingPathComponent("transcript.md")
            memory.writeFile(transcriptURL, content: terminal.output)
            appendTerminal("Transcript saved to \(sessionFolder.lastPathComponent)/\n")
        }

        // Update Chat-History
        if let chatPath = memory.chatHistoryPath {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy MMM dd HHmm"
            let lineCount = terminal.output.components(separatedBy: "\n").count
            let entry = "\n### [\(formatter.string(from: .now))] Session ended\n- \(lineCount) lines of terminal output\n"
            if var existing = memory.readFile(chatPath) {
                existing += entry
                memory.writeFile(chatPath, content: existing)
            }
            appendTerminal("Chat-History updated.\n")
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

            notes += "## Previous Session Summary\n\n"
            let sessionFormatter = DateFormatter()
            sessionFormatter.dateFormat = "yyyy MMM dd HHmm"
            notes += "- Session ended: \(sessionFormatter.string(from: .now))\n"

            memory.writeFile(morningPath, content: notes)
            appendTerminal("MORNING-NOTES written for tomorrow.\n")

            productionTitle = "MORNING-NOTES.md"
            setProduction(notes)
        }

        appendTerminal("\nSession saved. Safe to close.\n\n")
    }
}
