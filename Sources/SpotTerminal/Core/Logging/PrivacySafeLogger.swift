// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation
import OSLog

final class PrivacySafeLogger {
    static let shared = PrivacySafeLogger()

    private let maxLogBytes: UInt64 = 1_000_000
    private let osLog = Logger(subsystem: "cc.griffino.spotterminal", category: "diagnostics")
    private let queue = DispatchQueue(label: "cc.griffino.spotterminal.privacy-safe-log")
    private let dateFormatter: ISO8601DateFormatter
    let logURL: URL

    private init() {
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base
            .appendingPathComponent("SpotTerminal", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        logURL = directory.appendingPathComponent("diagnostics.log")
    }

    func event(_ name: String, metadata: [String: String] = [:]) {
        let safeMetadata = metadata
            .filter { Self.isSafeKey($0.key) }
            .mapValues(Self.redactedValue)
        osLog.info("\(name, privacy: .public)")
        queue.async { [dateFormatter, logURL] in
            self.rotateIfNeeded()
            let timestamp = dateFormatter.string(from: Date())
            let pairs = safeMetadata
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
            let line = pairs.isEmpty ? "\(timestamp) event=\(name)\n" : "\(timestamp) event=\(name) \(pairs)\n"
            guard let data = line.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: logURL.path),
               let handle = try? FileHandle(forWritingTo: logURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: logURL, options: .atomic)
            }
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: logURL.path)
        }
    }

    func clear() {
        queue.async { [logURL] in
            try? Data().write(to: logURL, options: .atomic)
        }
    }

    private static func isSafeKey(_ key: String) -> Bool {
        [
            "event",
            "state",
            "mode",
            "count",
            "exit_code",
            "duration_ms",
            "tab_count",
            "pane_count",
            "language",
            "permission",
            "granted"
        ].contains(key)
    }

    private static func redactedValue(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.")
        let filtered = String(value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
        return String(filtered.prefix(64))
    }

    private func rotateIfNeeded() {
        guard let values = try? logURL.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize,
              UInt64(size) > maxLogBytes else {
            return
        }
        try? Data().write(to: logURL, options: .atomic)
    }
}
