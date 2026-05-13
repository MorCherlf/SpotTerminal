// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import SpotTerminal
import Testing

@Suite("SystemDiagnostics")
struct SystemDiagnosticsTests {
    @Test func missingShellReportsProblem() {
        let items = SystemDiagnostics.snapshot(environment: [
            "SHELL": "/definitely/missing/zsh",
            "PATH": "/definitely/missing",
        ])

        let shell = items.first { $0.id == "shell" }
        #expect(shell?.severity == .problem)
    }

    @Test func nonZshShellReportsWarning() {
        let items = SystemDiagnostics.snapshot(environment: [
            "SHELL": "/bin/sh",
            "PATH": "/bin:/usr/bin",
        ])

        let shell = items.first { $0.id == "shell" }
        #expect(shell?.severity == .warning)
    }

    @Test func executableLookupFindsPathTool() {
        let path = SystemDiagnostics.executablePath(named: "sh", environment: [
            "PATH": "/bin:/usr/bin",
        ])

        #expect(path != nil)
    }
}
