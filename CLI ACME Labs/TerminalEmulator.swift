//
//  TerminalEmulator.swift
//  CLI ACME Labs
//
//  Created by Michael Fluharty on 4/10/26.
//
//  A real PTY-based terminal emulator. Spawns zsh and provides
//  full interactive shell access — ssh, claude, git, anything.
//

import Foundation

@Observable
class TerminalEmulator {
    var output = ""
    var isRunning = false

    private var process: Process?
    private var masterFD: Int32 = -1
    private var slaveFD: Int32 = -1
    private var readSource: DispatchSourceRead?

    func start(workingDirectory: String? = nil) {
        guard !isRunning else { return }

        // Open PTY pair
        var master: Int32 = 0
        var slave: Int32 = 0
        guard openpty(&master, &slave, nil, nil, nil) == 0 else {
            output += "Failed to open PTY.\n"
            return
        }
        masterFD = master
        slaveFD = slave

        // Set up the process
        process = Process()
        process?.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process?.arguments = ["--no-monitor"]

        // Build environment with claude in PATH
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "dumb"
        env["LANG"] = "en_US.UTF-8"
        let home = NSHomeDirectory()
        let extraPaths = "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin"
        if let existingPath = env["PATH"] {
            env["PATH"] = "\(extraPaths):\(existingPath)"
        } else {
            env["PATH"] = extraPaths
        }
        process?.environment = env

        if let dir = workingDirectory {
            process?.currentDirectoryURL = URL(fileURLWithPath: dir)
        }

        // Attach PTY to process
        let slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: false)
        process?.standardInput = slaveHandle
        process?.standardOutput = slaveHandle
        process?.standardError = slaveHandle

        // Read from master fd asynchronously
        let source = DispatchSource.makeReadSource(fileDescriptor: master, queue: .global())
        source.setEventHandler { [weak self] in
            var buffer = [UInt8](repeating: 0, count: 8192)
            let bytesRead = read(master, &buffer, buffer.count)
            if bytesRead > 0 {
                if let str = String(bytes: buffer[0..<bytesRead], encoding: .utf8) {
                    let cleaned = self?.stripAnsiCodes(str) ?? str
                    DispatchQueue.main.async {
                        self?.output += cleaned
                    }
                }
            }
        }
        source.setCancelHandler {
            close(master)
        }
        source.resume()
        readSource = source

        process?.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.output += "\n[Shell exited]\n"
            }
        }

        do {
            try process?.run()
            isRunning = true
            // Close slave in parent process — child owns it now
            close(slave)
        } catch {
            output += "Failed to start shell: \(error.localizedDescription)\n"
        }
    }

    func send(_ text: String) {
        guard isRunning, masterFD >= 0 else { return }
        let data = Array(text.utf8)
        write(masterFD, data, data.count)
    }

    func sendLine(_ text: String) {
        send(text + "\n")
    }

    func sendInterrupt() {
        // Send Ctrl+C
        send("\u{03}")
    }

    func sendEOF() {
        // Send Ctrl+D
        send("\u{04}")
    }

    func stop() {
        readSource?.cancel()
        readSource = nil
        process?.terminate()
        if masterFD >= 0 {
            close(masterFD)
            masterFD = -1
        }
        process = nil
        isRunning = false
    }

    func clear() {
        output = ""
    }

    /// Strip ANSI escape codes for clean text display
    private func stripAnsiCodes(_ text: String) -> String {
        // Remove CSI sequences (ESC [ ... letter/tilde)
        var result = text
        while let range = result.range(of: "\u{1B}\\[[0-9;?]*[A-Za-z~]", options: .regularExpression) {
            result.removeSubrange(range)
        }
        // Remove OSC sequences (ESC ] ... BEL or ST)
        while let range = result.range(of: "\u{1B}\\][^\u{07}\u{1B}]*[\u{07}]", options: .regularExpression) {
            result.removeSubrange(range)
        }
        while let range = result.range(of: "\u{1B}\\][^\u{1B}]*\u{1B}\\\\", options: .regularExpression) {
            result.removeSubrange(range)
        }
        // Remove single-character escapes
        while let range = result.range(of: "\u{1B}[()][AB012]", options: .regularExpression) {
            result.removeSubrange(range)
        }
        // Remove carriage returns
        result = result.replacingOccurrences(of: "\r", with: "")
        return result
    }

    deinit {
        stop()
    }
}
