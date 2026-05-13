// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation

enum DiagnosticSeverity: String, Equatable {
    case ok
    case warning
    case problem
}

struct DiagnosticItem: Identifiable, Equatable {
    var id: String
    var title: String
    var message: String
    var severity: DiagnosticSeverity
}

enum SystemDiagnostics {
    static func snapshot(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> [DiagnosticItem] {
        [
            shellItem(environment: environment, fileManager: fileManager),
            pathItem(environment: environment, fileManager: fileManager),
            toolItem("git", environment: environment, fileManager: fileManager),
            toolItem("docker", environment: environment, fileManager: fileManager),
            toolItem("kubectl", environment: environment, fileManager: fileManager),
            toolItem("gh", environment: environment, fileManager: fileManager),
        ]
    }

    static func executablePath(
        named name: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> String? {
        searchPaths(environment: environment).lazy
            .map { ($0 as NSString).appendingPathComponent(name) }
            .first { fileManager.isExecutableFile(atPath: $0) }
    }

    private static func shellItem(environment: [String: String], fileManager: FileManager) -> DiagnosticItem {
        let shell = environment["SHELL"] ?? "/bin/zsh"
        guard fileManager.isExecutableFile(atPath: shell) else {
            return DiagnosticItem(
                id: "shell",
                title: "Shell",
                message: "\(shell) is not executable",
                severity: .problem
            )
        }

        let shellName = URL(fileURLWithPath: shell).lastPathComponent
        let severity: DiagnosticSeverity = shellName == "zsh" ? .ok : .warning
        let message = shellName == "zsh"
            ? "\(shell) is ready"
            : "\(shell) works, but zsh gives the best completion coverage"
        return DiagnosticItem(id: "shell", title: "Shell", message: message, severity: severity)
    }

    private static func pathItem(environment: [String: String], fileManager: FileManager) -> DiagnosticItem {
        let paths = searchPaths(environment: environment)
        let existing = paths.filter { path in
            var isDirectory: ObjCBool = false
            return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
        guard !existing.isEmpty else {
            return DiagnosticItem(
                id: "path",
                title: "PATH",
                message: "No executable search directories were found",
                severity: .problem
            )
        }
        return DiagnosticItem(
            id: "path",
            title: "PATH",
            message: "\(existing.count) executable search directories available",
            severity: .ok
        )
    }

    private static func toolItem(
        _ name: String,
        environment: [String: String],
        fileManager: FileManager
    ) -> DiagnosticItem {
        if let path = executablePath(named: name, environment: environment, fileManager: fileManager) {
            return DiagnosticItem(
                id: "tool-\(name)",
                title: name,
                message: path,
                severity: .ok
            )
        }
        return DiagnosticItem(
            id: "tool-\(name)",
            title: name,
            message: "Not found; related completions will be limited",
            severity: .warning
        )
    }

    private static func searchPaths(environment: [String: String]) -> [String] {
        let rawPath = environment["PATH"] ?? ""
        let paths = rawPath.split(separator: ":").map(String.init)
        return Array(NSOrderedSet(array: paths + ["/bin", "/usr/bin", "/usr/local/bin", "/opt/homebrew/bin"]).compactMap { $0 as? String })
    }
}
