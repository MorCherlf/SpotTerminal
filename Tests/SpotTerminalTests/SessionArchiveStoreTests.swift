// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import SpotTerminal
import Testing

@Suite("SessionArchiveStore")
struct SessionArchiveStoreTests {
    @MainActor
    @Test func archivePersistsSessionRecordAndSummary() {
        let store = makeStore()
        let session = CommandSession(title: "Quick", startShell: false)
        session.append(entries: [
            CommandEntry(
                command: "echo hello",
                startedAt: Date(timeIntervalSince1970: 100),
                finishedAt: Date(timeIntervalSince1970: 101),
                output: "hello\n",
                state: .finished(exitCode: 0)
            )
        ])

        store.archive(session)

        let summaries = store.recentSummaries(limit: 10)
        #expect(summaries.count == 1)
        #expect(summaries[0].id == session.id)
        #expect(summaries[0].title == "Quick")
        #expect(summaries[0].firstCommand == "echo hello")
        #expect(summaries[0].commandCount == 1)

        let record = store.record(id: session.id)
        #expect(record?.entries.first?.command == "echo hello")
        #expect(record?.entries.first?.output == "hello\n")
        #expect(record?.entries.first?.state == .finished(exitCode: 0))
    }

    @MainActor
    @Test func archiveIgnoresEmptySessions() {
        let store = makeStore()
        let session = CommandSession(title: "Empty", startShell: false)

        store.archive(session)

        #expect(store.recentSummaries(limit: 10).isEmpty)
    }

    @MainActor
    @Test func recentCommandsDeduplicatesByCommand() {
        let store = makeStore()
        let session = CommandSession(title: "Quick", startShell: false)
        session.append(entries: [
            CommandEntry(command: "pwd", startedAt: Date(), finishedAt: Date(), output: "/tmp\n", state: .finished(exitCode: 0)),
            CommandEntry(command: "pwd", startedAt: Date(), finishedAt: Date(), output: "/tmp\n", state: .finished(exitCode: 0)),
            CommandEntry(command: "ls", startedAt: Date(), finishedAt: Date(), output: "README.md\n", state: .finished(exitCode: 0)),
        ])

        store.archive(session)

        let commands = store.recentCommands(limit: 10).map(\.command)
        #expect(commands == ["ls", "pwd"])
    }

    @MainActor
    @Test func searchSummariesMatchesCommandAndOutput() {
        let store = makeStore()
        let session = CommandSession(title: "Build", startShell: false)
        session.append(entries: [
            CommandEntry(command: "swift test", startedAt: Date(), finishedAt: Date(), output: "All tests passed\n", state: .finished(exitCode: 0))
        ])

        store.archive(session)

        #expect(store.searchSummaries(query: "swift").map(\.id) == [session.id])
        #expect(store.searchSummaries(query: "passed").map(\.id) == [session.id])
        #expect(store.searchSummaries(query: "missing").isEmpty)
    }

    @MainActor
    @Test func archiveCapsLargeOutput() {
        let store = makeStore()
        let session = CommandSession(title: "Large", startShell: false)
        let output = String(repeating: "x", count: 600_000)
        session.append(entries: [
            CommandEntry(command: "large-output", startedAt: Date(), finishedAt: Date(), output: output, state: .finished(exitCode: 0))
        ])

        store.archive(session)

        let record = store.record(id: session.id)
        #expect(record?.entries.first?.output.count == 500_000)
    }

    @Test func oversizedArchiveFilesAreIgnored() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpotTerminalTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let oversized = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        let data = Data(repeating: 0x20, count: 5_000_001)
        try data.write(to: oversized)
        let store = SessionArchiveStore(directory: directory)

        #expect(store.recentSummaries(limit: 10).isEmpty)
    }

    private func makeStore() -> SessionArchiveStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpotTerminalTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return SessionArchiveStore(directory: directory)
    }
}
