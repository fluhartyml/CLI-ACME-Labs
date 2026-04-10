//
//  FileWatcher.swift
//  CLI ACME Labs
//
//  Created by Michael Fluharty on 4/10/26.
//
//  Watches files on disk and fires a callback when they change.
//  Used to drive the production and pinned panes from drop files.
//

import Foundation

class FileWatcher {
    private var timer: Timer?
    private var lastModified: [URL: Date] = [:]
    private var callbacks: [URL: (String) -> Void] = [:]

    func watch(_ url: URL, onChange: @escaping (String) -> Void) {
        callbacks[url] = onChange
        // Read initial content if file exists
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            lastModified[url] = modificationDate(for: url)
            if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                onChange(content)
            }
        }
        startPolling()
    }

    func unwatch(_ url: URL) {
        callbacks.removeValue(forKey: url)
        lastModified.removeValue(forKey: url)
        if callbacks.isEmpty {
            stopPolling()
        }
    }

    func unwatchAll() {
        callbacks.removeAll()
        lastModified.removeAll()
        stopPolling()
    }

    private func startPolling() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func checkForChanges() {
        for (url, callback) in callbacks {
            let currentMod = modificationDate(for: url)
            let previousMod = lastModified[url]

            if currentMod != previousMod {
                lastModified[url] = currentMod
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    DispatchQueue.main.async {
                        callback(content)
                    }
                }
            }
        }
    }

    private func modificationDate(for url: URL) -> Date? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    deinit {
        stopPolling()
    }
}
