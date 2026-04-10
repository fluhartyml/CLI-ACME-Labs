//
//  CLI_ACME_LabsApp.swift
//  CLI ACME Labs
//
//  Created by Michael Fluharty on 11/10/25.
//

import SwiftUI

@main
struct CLI_ACME_LabsApp: App {
    var body: some Scene {
        WindowGroup {
            TerminalView()
                .frame(minWidth: 800, minHeight: 600)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
    }
}
