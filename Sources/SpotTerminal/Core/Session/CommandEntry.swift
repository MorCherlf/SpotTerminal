// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation

enum CommandRunState: Equatable {
    case running
    case finished(exitCode: Int32)
    case interrupted
}

struct CommandEntry: Identifiable, Equatable {
    let id = UUID()
    var command: String
    var startedAt = Date()
    var finishedAt: Date?
    var output = ""
    var state: CommandRunState = .running

    var duration: TimeInterval {
        (finishedAt ?? Date()).timeIntervalSince(startedAt)
    }

    var exitCodeForLog: Int32 {
        switch state {
        case .running:
            return -1
        case .finished(let exitCode):
            return exitCode
        case .interrupted:
            return 130
        }
    }

    init(command: String) {
        self.command = command
    }

    init(command: String, startedAt: Date, finishedAt: Date?, output: String, state: CommandRunState) {
        self.command = command
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.output = output
        self.state = state
    }
}
