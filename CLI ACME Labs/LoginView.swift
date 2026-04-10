//
//  LoginView.swift
//  CLI ACME Labs
//
//  Created by Michael Fluharty on 4/10/26.
//

import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var apiKey = ""
    var onSave: (String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Authenticate with Anthropic")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.green)

            Text("1. Click below to open the Anthropic Console\n2. Create or copy your API key\n3. Paste it here")
                .font(.system(size: 18, design: .monospaced))
                .foregroundStyle(.green.opacity(0.7))
                .multilineTextAlignment(.center)

            Button("Open Anthropic Console") {
                if let url = URL(string: "https://console.anthropic.com/settings/keys") {
                    openURL(url)
                }
            }
            .font(.system(size: 18, design: .monospaced))
            .buttonStyle(.bordered)

            SecureField("Paste your key here", text: $apiKey)
                .font(.system(size: 18, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 500)

            Text("Stored securely in your Keychain.")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(.green.opacity(0.4))

            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Authenticate") {
                    onSave(apiKey)
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty)
            }
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 350)
        .background(Color.black)
    }
}
