//
//  CommandPickerView.swift
//  CLI ACME Labs
//
//  Created by Michael Fluharty on 4/10/26.
//

import SwiftUI

struct CommandPickerView: View {
    let commands: [(name: String, description: String)]
    let selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(commands.enumerated()), id: \.offset) { index, cmd in
                HStack {
                    Text(cmd.name)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                    Spacer()
                    Text(cmd.description)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.green.opacity(0.5))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(index == selectedIndex
                            ? Color.green.opacity(0.2)
                            : Color.clear)
            }
        }
        .background(Color.black.opacity(0.95))
        .overlay(
            Rectangle()
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}
