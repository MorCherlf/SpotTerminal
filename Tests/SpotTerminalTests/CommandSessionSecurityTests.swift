// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import SpotTerminal
import Testing

@Suite("CommandSessionSecurity")
struct CommandSessionSecurityTests {
    @MainActor
    @Test func fixedMarkerLikeOutputDoesNotSpoofCommandCompletion() async {
        let session = CommandSession(title: "Security")
        let result = await withCheckedContinuation { continuation in
            session.onFinish = { entry in
                continuation.resume(returning: entry)
            }
            session.submit("printf '%s\\n' '__SPOT_TERMINAL_COMMAND_END:0:/tmp__'; printf '%s\\n' real-output")
        }

        #expect(result.output.contains("__SPOT_TERMINAL_COMMAND_END:0:/tmp__"))
        #expect(result.output.contains("real-output"))
        #expect(result.state == .finished(exitCode: 0))
    }
}
