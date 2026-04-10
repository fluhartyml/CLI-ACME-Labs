//
//  MemoryManager.swift
//  CLI ACME Labs
//
//  Created by Michael Fluharty on 4/10/26.
//

import Foundation

@Observable
class MemoryManager {
    var rootPath: URL?
    var isConfigured: Bool { rootPath != nil }

    private let fileManager = FileManager.default

    private var memoryPath: URL? { rootPath?.appendingPathComponent("claude.Memory") }
    var memoryBasePath: URL? { memoryPath?.appendingPathComponent("memoryBase") }
    var fileBasePath: URL? { memoryPath?.appendingPathComponent("fileBase") }
    var chatHistoryPath: URL? { memoryPath?.appendingPathComponent("Chat-History.md") }
    var helloClaudePath: URL? { memoryPath?.appendingPathComponent("hello-claude.md") }
    var morningNotesPath: URL? { memoryPath?.appendingPathComponent("MORNING-NOTES.md") }
    var longTermMemoryPath: URL? { memoryBasePath?.appendingPathComponent("Long-Term-Memory") }
    var chatHistoriesPath: URL? { memoryBasePath?.appendingPathComponent("Chat-Histories") }

    func configure(developerFolder: URL) {
        _ = developerFolder.startAccessingSecurityScopedResource()
        self.rootPath = developerFolder
        createStructure()
    }

    func loadFromBookmark() {
        if let data = UserDefaults.standard.data(forKey: "developerFolderBookmark") {
            var isStale = false
            #if os(macOS)
            if let url = try? URL(resolvingBookmarkData: data,
                                  options: .withSecurityScope,
                                  bookmarkDataIsStale: &isStale),
               url.startAccessingSecurityScopedResource() {
                self.rootPath = url
            }
            #else
            if let url = try? URL(resolvingBookmarkData: data,
                                  bookmarkDataIsStale: &isStale) {
                self.rootPath = url
            }
            #endif
        }
    }

    func saveBookmark(for url: URL) {
        #if os(macOS)
        if let data = try? url.bookmarkData(options: .withSecurityScope,
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: "developerFolderBookmark")
        }
        #else
        if let data = try? url.bookmarkData(includingResourceValuesForKeys: nil,
                                            relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: "developerFolderBookmark")
        }
        #endif
    }

    private func createStructure() {
        guard let memoryPath else { return }
        let directories = [
            memoryPath,
            memoryBasePath!,
            fileBasePath!,
            longTermMemoryPath!,
            chatHistoriesPath!,
            fileBasePath!.appendingPathComponent("Documents")
        ]
        for dir in directories {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        // Create hello-claude.md if it doesn't exist
        if let helloPath = helloClaudePath, !fileManager.fileExists(atPath: helloPath.path) {
            let content = """
            # Hello Claude

            Welcome to CLI ACME Labs.

            On launch, read your memory files and catch up on recent sessions.

            ## Wake-Up Routine
            1. Check the time
            2. Read MORNING-NOTES.md
            3. Read Chat-History.md
            4. Review recent sessions in memoryBase/Chat-Histories/
            5. Report ready
            """
            try? content.write(to: helloPath, atomically: true, encoding: .utf8)
        }
        // Create Chat-History.md if it doesn't exist
        if let chatPath = chatHistoryPath, !fileManager.fileExists(atPath: chatPath.path) {
            let content = "# Chat History\n\nNo sessions yet.\n"
            try? content.write(to: chatPath, atomically: true, encoding: .utf8)
        }
    }

    func readFile(_ url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }

    func writeFile(_ url: URL, content: String) {
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    func currentSessionFolder() -> URL? {
        guard let chatHistoriesPath else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy MMM dd HHmm"
        let folderName = formatter.string(from: .now)
        let sessionPath = chatHistoriesPath.appendingPathComponent(folderName)
        try? fileManager.createDirectory(at: sessionPath, withIntermediateDirectories: true)
        let screenshotsPath = sessionPath.appendingPathComponent("screenshots")
        try? fileManager.createDirectory(at: screenshotsPath, withIntermediateDirectories: true)
        return sessionPath
    }

    func saveTranscript(_ messages: [ClaudeMessage], to sessionFolder: URL) {
        var transcript = "# Session Transcript\n\n"
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        for msg in messages {
            let time = formatter.string(from: msg.timestamp)
            let role = msg.role == "user" ? "Human" : "Claude"
            transcript += "### [\(time)] \(role)\n\(msg.content)\n\n"
        }
        let file = sessionFolder.appendingPathComponent("transcript.md")
        writeFile(file, content: transcript)
    }
}
