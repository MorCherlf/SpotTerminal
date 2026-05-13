// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation

@MainActor
final class CommandSession: ObservableObject, Identifiable {
    private static let maxCommandLength = 8_192
    private static let maxStoredOutputLength = 2_000_000

    let id = UUID()
    let title: String

    @Published private(set) var entries: [CommandEntry] = []
    @Published private(set) var isRunning = false
    @Published private(set) var currentDirectory = FileManager.default.homeDirectoryForCurrentUser.path

    nonisolated let shellSession = PersistentShellSession()
    var onFinish: ((CommandEntry) -> Void)?

    init(title: String, startShell: Bool = true) {
        self.title = title
        shellSession.onCommandOutput = { [weak self] text in
            Task { @MainActor in
                self?.appendOutput(text)
            }
        }
        shellSession.onCommandFinished = { [weak self] exitCode in
            Task { @MainActor in
                self?.finish(exitCode: exitCode)
            }
        }
        shellSession.onWorkingDirectoryChanged = { [weak self] path in
            Task { @MainActor in
                self?.currentDirectory = path
            }
        }
        if startShell {
            shellSession.startIfNeeded()
        }
    }

    func submit(_ rawCommand: String) {
        let command = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty, !isRunning else { return }
        guard command.count <= Self.maxCommandLength else {
            PrivacySafeLogger.shared.event("command_rejected", metadata: ["state": "too_long"])
            return
        }

        entries.append(CommandEntry(command: command))
        isRunning = true
        PrivacySafeLogger.shared.event("command_started")

        shellSession.submit(command)
    }

    func sendInteractiveInput(_ rawInput: String) {
        guard isRunning else { return }
        let bytes = Array((rawInput + "\n").utf8)
        shellSession.send(data: bytes[...])
    }

    func interrupt() {
        guard isRunning else { return }
        shellSession.interrupt()
    }

    func forceKill() {
        guard isRunning else { return }
        shellSession.forceKill()
    }

    func append(entries newEntries: [CommandEntry]) {
        entries.append(contentsOf: newEntries)
    }

    private func appendOutput(_ text: String) {
        guard let index = entries.indices.last else { return }
        var updated = entries
        updated[index].output += text
        if updated[index].output.count > Self.maxStoredOutputLength {
            updated[index].output = String(updated[index].output.suffix(Self.maxStoredOutputLength))
        }
        entries = updated
    }

    private func finish(exitCode: Int32) {
        guard isRunning else { return }
        guard let index = entries.indices.last else { return }
        var updated = entries
        updated[index].finishedAt = Date()
        updated[index].state = exitCode == 130 ? .interrupted : .finished(exitCode: exitCode)
        entries = updated
        isRunning = false
        PrivacySafeLogger.shared.event(
            "command_finished",
            metadata: [
                "exit_code": "\(exitCode)",
                "duration_ms": "\(Int(updated[index].duration * 1000))"
            ]
        )
        onFinish?(updated[index])
    }
}
