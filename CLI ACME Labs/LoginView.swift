//
//  LoginView.swift
//  CLI ACME Labs
//
//  Created by Michael Fluharty on 4/10/26.
//

import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    var onSave: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Anthropic API Key")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.green)

            Text("Enter your API key from console.anthropic.com.\nIt will be stored securely in your Keychain.")
                .font(.system(size: 18, design: .monospaced))
                .foregroundStyle(.green.opacity(0.7))
                .multilineTextAlignment(.center)

            SecureField("sk-ant-...", text: $apiKey)
                .font(.system(size: 18, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 500)

            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    onSave(apiKey)
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty)
            }
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 300)
        .background(Color.black)
    }
}
