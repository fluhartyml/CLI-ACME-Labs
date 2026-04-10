//
//  ProductionPaneView.swift
//  CLI ACME Labs
//
//  Created by Michael Fluharty on 4/10/26.
//

import SwiftUI

enum LineStatus {
    case unchanged
    case added
    case removed
    case modified
}

struct NumberedLine: Identifiable {
    let id: Int
    let number: Int
    let content: String
    let status: LineStatus
}

struct ProductionPaneView: View {
    let text: String
    var previousText: String = ""

    private var numberedLines: [NumberedLine] {
        let currentLines = text.components(separatedBy: "\n")
        let previousLines = previousText.components(separatedBy: "\n")

        if previousText.isEmpty {
            // No previous version — everything is plain
            return currentLines.enumerated().map {
                NumberedLine(id: $0.offset, number: $0.offset + 1,
                            content: $0.element, status: .unchanged)
            }
        }

        // Diff: compare line by line
        var result: [NumberedLine] = []
        let maxCount = max(currentLines.count, previousLines.count)

        for i in 0..<maxCount {
            let currentLine = i < currentLines.count ? currentLines[i] : nil
            let previousLine = i < previousLines.count ? previousLines[i] : nil

            if let current = currentLine, let previous = previousLine {
                if current == previous {
                    result.append(NumberedLine(id: i, number: i + 1,
                                              content: current, status: .unchanged))
                } else {
                    // Show the removed line
                    result.append(NumberedLine(id: maxCount + i, number: i + 1,
                                              content: previous, status: .removed))
                    // Show the new line
                    result.append(NumberedLine(id: maxCount * 2 + i, number: i + 1,
                                              content: current, status: .added))
                }
            } else if let current = currentLine {
                // Line was added (new content beyond previous length)
                result.append(NumberedLine(id: i, number: i + 1,
                                          content: current, status: .added))
            } else if let previous = previousLine {
                // Line was removed
                result.append(NumberedLine(id: maxCount + i, number: i + 1,
                                          content: previous, status: .removed))
            }
        }

        return result
    }

    private var gutterWidth: CGFloat {
        let lineCount = text.components(separatedBy: "\n").count
        let maxDigits = String(lineCount).count
        return CGFloat(maxDigits) * 10 + 20
    }

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            HStack(alignment: .top, spacing: 0) {
                // Line number gutter
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(numberedLines) { line in
                        HStack(spacing: 2) {
                            Text(statusPrefix(for: line.status))
                                .font(.system(size: 18, design: .monospaced))
                                .foregroundStyle(gutterColor(for: line.status))
                                .frame(width: 14)
                            Text(line.status == .removed ? "—" : "\(line.number)")
                                .font(.system(size: 18, design: .monospaced))
                                .foregroundStyle(gutterColor(for: line.status))
                        }
                        .frame(height: 24)
                    }
                }
                .frame(width: gutterWidth)
                .padding(.leading, 8)

                // Separator
                Rectangle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 1)
                    .padding(.horizontal, 4)

                // Content
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(numberedLines) { line in
                        Text(line.content.isEmpty ? " " : line.content)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(textColor(for: line.status))
                            .strikethrough(line.status == .removed, color: .red.opacity(0.6))
                            .textSelection(.enabled)
                            .frame(height: 24, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(highlightColor(for: line.status))
                    }
                }
                .padding(.trailing, 8)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
        }
        .background(Color.black)
    }

    private func textColor(for status: LineStatus) -> Color {
        switch status {
        case .unchanged: return .green
        case .added: return .green
        case .removed: return .red.opacity(0.6)
        case .modified: return .yellow
        }
    }

    private func gutterColor(for status: LineStatus) -> Color {
        switch status {
        case .unchanged: return .green.opacity(0.4)
        case .added: return .green.opacity(0.8)
        case .removed: return .red.opacity(0.5)
        case .modified: return .yellow.opacity(0.6)
        }
    }

    private func statusPrefix(for status: LineStatus) -> String {
        switch status {
        case .unchanged: return " "
        case .added: return "+"
        case .removed: return "-"
        case .modified: return "~"
        }
    }

    private func highlightColor(for status: LineStatus) -> Color {
        switch status {
        case .unchanged: return .clear
        case .added: return .green.opacity(0.1)
        case .removed: return .red.opacity(0.1)
        case .modified: return .yellow.opacity(0.1)
        }
    }
}
