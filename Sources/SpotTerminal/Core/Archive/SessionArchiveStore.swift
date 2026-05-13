// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation

struct ArchivedSessionSummary: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var createdAt: Date
    var archivedAt: Date
    var firstCommand: String
    var commandCount: Int
}

struct ArchivedSessionRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var createdAt: Date
    var archivedAt: Date
    var entries: [ArchivedCommandEntry]

    var summary: ArchivedSessionSummary {
        ArchivedSessionSummary(
            id: id,
            title: title,
            createdAt: createdAt,
            archivedAt: archivedAt,
            firstCommand: entries.first?.command ?? title,
            commandCount: entries.count
        )
    }
}

struct ArchivedCommandEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var command: String
    var startedAt: Date
    var finishedAt: Date?
    var output: String
    var state: ArchivedCommandState
}

enum ArchivedCommandState: Codable, Equatable {
    case running
    case finished(exitCode: Int32)
    case interrupted
}

final class SessionArchiveStore {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let maxArchiveCount = 500
    private let maxArchiveAge: TimeInterval = 30 * 24 * 60 * 60
    private let maxArchiveFileBytes: Int64 = 5_000_000

    init(fileManager: FileManager = .default, directory: URL? = nil) {
        if let directory {
            self.directory = directory
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            decoder.dateDecodingStrategy = .iso8601
            return
        }

        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        self.directory = applicationSupport
            .appendingPathComponent("Spot Terminal", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    @MainActor
    func archive(_ session: CommandSession) {
        guard !session.entries.isEmpty else { return }
        let record = ArchivedSessionRecord(
            id: session.id,
            title: session.title,
            createdAt: session.entries.first?.startedAt ?? Date(),
            archivedAt: Date(),
            entries: session.entries.map(ArchivedCommandEntry.init(entry:))
        )

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let data = try encoder.encode(record)
            let url = fileURL(for: record.id)
            try data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            cleanup()
        } catch {
            NSLog("SpotTerminal archive write failed: \(error.localizedDescription)")
        }
    }

    func recentSummaries(limit: Int = 5) -> [ArchivedSessionSummary] {
        archiveRecords()
            .sorted { $0.archivedAt > $1.archivedAt }
            .prefix(limit)
            .map(\.summary)
    }

    func recentCommands(limit: Int = 5) -> [ArchivedCommandMatch] {
        archiveRecords()
            .sorted { $0.archivedAt > $1.archivedAt }
            .flatMap { record in
                record.entries.reversed().map { entry in
                    ArchivedCommandMatch(
                        id: "\(record.id.uuidString)-\(entry.id.uuidString)",
                        command: entry.command,
                        sessionTitle: record.title,
                        archivedAt: record.archivedAt
                    )
                }
            }
            .uniquedByCommand()
            .prefix(limit)
            .map { $0 }
    }

    func searchCommands(query: String, limit: Int = 3) -> [ArchivedCommandMatch] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return recentCommands(limit: limit) }

        return archiveRecords()
            .flatMap { record in
                record.entries.compactMap { entry -> ArchivedCommandMatch? in
                    guard entry.command.lowercased().contains(normalizedQuery) else { return nil }
                    return ArchivedCommandMatch(
                        id: "\(record.id.uuidString)-\(entry.id.uuidString)",
                        command: entry.command,
                        sessionTitle: record.title,
                        archivedAt: record.archivedAt
                    )
                }
            }
            .sorted { $0.archivedAt > $1.archivedAt }
            .uniquedByCommand()
            .prefix(limit)
            .map { $0 }
    }

    func searchSummaries(query: String, limit: Int = 2) -> [ArchivedSessionSummary] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return recentSummaries(limit: limit) }

        return archiveRecords()
            .filter { record in
                record.title.lowercased().contains(normalizedQuery)
                    || record.entries.contains { entry in
                        entry.command.lowercased().contains(normalizedQuery)
                            || entry.output.lowercased().contains(normalizedQuery)
                    }
            }
            .sorted { $0.archivedAt > $1.archivedAt }
            .prefix(limit)
            .map(\.summary)
    }

    func record(id: UUID) -> ArchivedSessionRecord? {
        guard let data = try? Data(contentsOf: fileURL(for: id)) else { return nil }
        return try? decoder.decode(ArchivedSessionRecord.self, from: data)
    }

    private func archiveRecords() -> [ArchivedSessionRecord] {
        do {
            return try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> ArchivedSessionRecord? in
                guard isSafeArchiveFile(url),
                      let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(ArchivedSessionRecord.self, from: data)
            }
        } catch {
            return []
        }
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }

    private func cleanup() {
        let records = archiveRecordsWithURLs()
            .sorted { $0.record.archivedAt > $1.record.archivedAt }
        let cutoff = Date().addingTimeInterval(-maxArchiveAge)
        let expired = records.filter { $0.record.archivedAt < cutoff }
        let overLimit = records.dropFirst(maxArchiveCount)

        for item in expired + overLimit {
            try? FileManager.default.removeItem(at: item.url)
        }
    }

    private func archiveRecordsWithURLs() -> [(url: URL, record: ArchivedSessionRecord)] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard isSafeArchiveFile(url),
                      let data = try? Data(contentsOf: url),
                      let record = try? decoder.decode(ArchivedSessionRecord.self, from: data) else {
                    return nil
                }
                return (url: url, record: record)
            }
    }

    private func isSafeArchiveFile(_ url: URL) -> Bool {
        guard url.pathExtension == "json",
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true,
              Int64(values.fileSize ?? 0) <= maxArchiveFileBytes else {
            return false
        }
        return true
    }
}

private extension Array where Element == ArchivedCommandMatch {
    func uniquedByCommand() -> [ArchivedCommandMatch] {
        var seen: Set<String> = []
        return filter { match in
            seen.insert(match.command).inserted
        }
    }
}

private extension ArchivedCommandEntry {
    init(entry: CommandEntry) {
        id = entry.id
        command = entry.command
        startedAt = entry.startedAt
        finishedAt = entry.finishedAt
        output = entry.output.cappedArchiveOutput()
        state = ArchivedCommandState(state: entry.state)
    }
}

private extension String {
    func cappedArchiveOutput(limit: Int = 500_000) -> String {
        guard count > limit else { return self }
        return String(suffix(limit))
    }
}

private extension ArchivedCommandState {
    init(state: CommandRunState) {
        switch state {
        case .running:
            self = .running
        case .finished(let exitCode):
            self = .finished(exitCode: exitCode)
        case .interrupted:
            self = .interrupted
        }
    }
}
