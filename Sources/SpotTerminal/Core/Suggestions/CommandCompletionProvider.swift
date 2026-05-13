// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation

final class CommandCompletionProvider {
    private var commandIndex: [String: CompletionMetadata] = [:]
    private var zshCompletionFunctions: [String: String] = [:]
    private var loadedAt: Date?
    private let lock = NSLock()
    private let refreshInterval: TimeInterval = 60
    private let shellBuiltins = [
        "alias", "bg", "cd", "clear", "dirs", "disown", "echo", "eval",
        "exec", "exit", "export", "fg", "history", "jobs", "popd", "pushd",
        "pwd", "read", "set", "source", "test", "type", "ulimit", "unalias",
        "unset", "wait"
    ]

    func complete(prefix: String, workingDirectory: String, limit: Int) -> [CompletionMatch] {
        if let directoryCompletions = completeDirectoryChange(prefix: prefix, workingDirectory: workingDirectory, limit: limit) {
            return directoryCompletions
        }
        if let gitCompletions = completeGitSubcommand(prefix: prefix, workingDirectory: workingDirectory, limit: limit) {
            return gitCompletions
        }
        if let dockerCompletions = completeDockerSubcommand(prefix: prefix, limit: limit) {
            return dockerCompletions
        }
        if let kubectlCompletions = completeKubectlSubcommand(prefix: prefix, limit: limit) {
            return kubectlCompletions
        }
        if let ghCompletions = completeGhSubcommand(prefix: prefix, workingDirectory: workingDirectory, limit: limit) {
            return ghCompletions
        }
        if let argumentCompletions = completeArgumentPath(prefix: prefix, workingDirectory: workingDirectory, limit: limit) {
            return argumentCompletions
        }

        refreshIfNeeded()
        let query = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, query.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return []
        }

        return snapshot()
            .compactMap { command, metadata -> (CompletionMatch, Int)? in
                guard let score = fuzzyScore(command, query: query) else { return nil }
                return (
                    CompletionMatch(
                        command: command,
                        subtitle: metadata.subtitle,
                        sectionTitle: metadata.sectionTitle,
                        systemImage: metadata.systemImage
                    ),
                    score + metadata.scoreBoost
                )
            }
            .sorted {
                if $0.1 == $1.1 { return $0.0.command < $1.0.command }
                return $0.1 > $1.1
            }
            .prefix(limit)
            .map(\.0)
    }

    private func refreshIfNeeded() {
        lock.lock()
        let shouldRefresh = loadedAt.map { Date().timeIntervalSince($0) >= refreshInterval } ?? true
        lock.unlock()

        guard shouldRefresh else {
            return
        }

        var index: [String: CompletionMetadata] = [:]
        shellBuiltins.forEach { index[$0] = CompletionMetadata(kind: .builtin) }

        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let searchPaths = (path.split(separator: ":").map(String.init) + ["/bin", "/usr/bin", "/usr/local/bin", "/opt/homebrew/bin"])

        for directory in searchPaths {
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory) else { continue }
            for entry in entries {
                let fullPath = (directory as NSString).appendingPathComponent(entry)
                if FileManager.default.isExecutableFile(atPath: fullPath) {
                    index[entry] = index[entry] ?? CompletionMetadata(kind: .executable)
                }
            }
        }

        lock.lock()
        commandIndex = index
        loadedAt = Date()
        lock.unlock()

        enrichFromZshInBackground()
    }

    private func snapshot() -> [(String, CompletionMetadata)] {
        lock.lock()
        defer { lock.unlock() }
        return commandIndex.map { ($0.key, $0.value) }
    }

    private func zshCompletionFunction(for command: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return zshCompletionFunctions[command]
    }

    private func enrichFromZshInBackground() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self, let zshEnvironment = self.loadZshEnvironment() else { return }

            self.lock.lock()
            for (name, metadata) in zshEnvironment.entries {
                self.commandIndex[name] = self.commandIndex[name]?.merged(with: metadata) ?? metadata
            }
            self.zshCompletionFunctions = zshEnvironment.completionFunctions
            self.loadedAt = Date()
            self.lock.unlock()
        }
    }

    private func loadZshEnvironment() -> ZshCompletionEnvironment? {
        let shellPath = ProcessInfo.processInfo.environment["SHELL"].flatMap { shell -> String? in
            Self.isSupportedZsh(shell) ? shell : nil
        } ?? "/bin/zsh"
        guard FileManager.default.isExecutableFile(atPath: shellPath) else { return nil }

        let script = """
        emulate -L zsh
        setopt no_nomatch
        autoload -Uz compinit
        compinit -C >/dev/null 2>&1
        for name value in ${(kv)aliases}; do
          print -r -- alias:${name}:${value}
        done
        print -rl -- ${(k)functions/#/function:}
        print -rl -- ${(k)builtins/#/builtin:}
        print -rl -- ${(k)commands/#/command:}
        for name value in ${(kv)_comps}; do
          print -r -- compdef:${name}:${value}
        done
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = ["-lic", script]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "SPOT_TERMINAL_COMPLETION_SCAN": "1"
        ]) { current, _ in current }

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let finished = wait(process: process, timeout: 2.0)
        guard finished else {
            process.terminate()
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        var entries: [String: CompletionMetadata] = [:]
        var completionFunctions: [String: String] = [:]
        for line in output.split(separator: "\n").map(String.init) {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let rawKind = String(line[..<separator])
            let remainder = String(line[line.index(after: separator)...])
            let name: String
            let detail: String?
            if rawKind == "alias",
               let detailSeparator = remainder.firstIndex(of: ":") {
                name = String(remainder[..<detailSeparator])
                detail = String(remainder[remainder.index(after: detailSeparator)...])
            } else {
                name = remainder
                detail = nil
            }
            guard !name.isEmpty else { continue }

            switch rawKind {
            case "alias":
                entries[name] = CompletionMetadata(kind: .zshAlias, detail: detail)
            case "function":
                entries[name] = CompletionMetadata(kind: .zshFunction)
            case "builtin":
                entries[name] = CompletionMetadata(kind: .builtin)
            case "command":
                entries[name] = entries[name] ?? CompletionMetadata(kind: .executable)
            case "compdef":
                if let detailSeparator = remainder.firstIndex(of: ":") {
                    let command = String(remainder[..<detailSeparator])
                    let function = String(remainder[remainder.index(after: detailSeparator)...])
                    if !command.isEmpty, !function.isEmpty {
                        completionFunctions[command] = function
                    }
                }
            default:
                break
            }
        }
        return ZshCompletionEnvironment(entries: entries, completionFunctions: completionFunctions)
    }

    private static func isSupportedZsh(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return url.path == path
            && url.path.hasPrefix("/")
            && url.lastPathComponent == "zsh"
            && FileManager.default.isExecutableFile(atPath: path)
    }

    private func wait(process: Process, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Date() >= deadline {
                return false
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        return true
    }

    private func completeDirectoryChange(prefix: String, workingDirectory: String, limit: Int) -> [CompletionMatch]? {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == "cd" || trimmed.hasPrefix("cd ") else { return nil }

        let rawPathPrefix = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        let search = directorySearchContext(for: rawPathPrefix, workingDirectory: workingDirectory)

        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: search.directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return entries
            .filter { url in
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                    return false
                }
                guard !search.namePrefix.isEmpty else { return true }
                return url.lastPathComponent.lowercased().hasPrefix(search.namePrefix.lowercased())
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .prefix(limit)
            .map { url in
                CompletionMatch(
                    command: "cd \(shellEscaped(search.displayPrefix + url.lastPathComponent))",
                    subtitle: "Directory",
                    sectionTitle: "Directories",
                    systemImage: "folder"
                )
            }
    }

    private func completeArgumentPath(prefix: String, workingDirectory: String, limit: Int) -> [CompletionMatch]? {
        let commandLine = prefix.trimmingCharacters(in: .newlines)
        guard commandLine.rangeOfCharacter(from: .whitespacesAndNewlines) != nil else { return nil }
        guard let context = shellWordContext(for: commandLine) else { return nil }

        let pathPrefix = context.currentWord
        guard pathPrefix.isEmpty
            || pathPrefix.hasPrefix("/")
            || pathPrefix.hasPrefix("~")
            || pathPrefix.hasPrefix(".")
            || pathPrefix.contains("/") else {
            return nil
        }

        let search = directorySearchContext(for: pathPrefix, workingDirectory: workingDirectory)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: search.directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let completionFunction = zshCompletionFunction(for: context.command)
        let subtitle = completionFunction.map { "Path candidate via \($0)" } ?? "Path candidate"

        return entries
            .filter { url in
                guard !search.namePrefix.isEmpty else { return true }
                return url.lastPathComponent.localizedCaseInsensitiveContains(search.namePrefix)
            }
            .sorted { lhs, rhs in
                let lhsDirectory = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                let rhsDirectory = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                if lhsDirectory != rhsDirectory { return lhsDirectory }
                return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
            }
            .prefix(limit)
            .map { url in
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                let replacement = search.displayPrefix + url.lastPathComponent + (isDirectory ? "/" : "")
                return CompletionMatch(
                    command: context.prefixBeforeCurrentWord + shellEscaped(replacement),
                    subtitle: subtitle,
                    sectionTitle: completionFunction == nil ? "Path Candidates" : "zsh Completion Paths",
                    systemImage: isDirectory ? "folder" : "doc"
                )
            }
    }

    private func directorySearchContext(for rawPathPrefix: String, workingDirectory: String) -> (directoryURL: URL, namePrefix: String, displayPrefix: String) {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let workingDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)

        guard !rawPathPrefix.isEmpty else {
            return (workingDirectoryURL, "", "")
        }

        let expandedPath: String
        if rawPathPrefix == "~" {
            expandedPath = home.path
        } else if rawPathPrefix.hasPrefix("~/") {
            expandedPath = home.appendingPathComponent(String(rawPathPrefix.dropFirst(2))).path
        } else if rawPathPrefix.hasPrefix("/") {
            expandedPath = rawPathPrefix
        } else {
            expandedPath = workingDirectoryURL.appendingPathComponent(rawPathPrefix).path
        }

        let candidateURL = URL(fileURLWithPath: expandedPath)
        let directoryURL = rawPathPrefix.hasSuffix("/") ? candidateURL : candidateURL.deletingLastPathComponent()
        let namePrefix = rawPathPrefix.hasSuffix("/") ? "" : candidateURL.lastPathComponent
        let separatorRange = rawPathPrefix.range(of: "/", options: .backwards)
        let displayPrefix = separatorRange.map { String(rawPathPrefix[..<$0.upperBound]) } ?? ""
        return (directoryURL, namePrefix, displayPrefix)
    }

    private func shellEscaped(_ value: String) -> String {
        guard !value.isEmpty else { return value }
        guard value.rangeOfCharacter(from: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "'\"\\$`"))) != nil else {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func shellWordContext(for commandLine: String) -> ShellWordContext? {
        var words: [String] = []
        var current = ""
        var currentStart = commandLine.startIndex
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaped = false

        for index in commandLine.indices {
            let character = commandLine[index]
            if escaped {
                current.append(character)
                escaped = false
                continue
            }
            if character == "\\" {
                escaped = true
                continue
            }
            if character == "'", !inDoubleQuote {
                inSingleQuote.toggle()
                continue
            }
            if character == "\"", !inSingleQuote {
                inDoubleQuote.toggle()
                continue
            }
            if character.isWhitespace, !inSingleQuote, !inDoubleQuote {
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
                currentStart = commandLine.index(after: index)
            } else {
                current.append(character)
            }
        }

        guard let command = words.first else { return nil }
        return ShellWordContext(
            command: command,
            currentWord: current,
            prefixBeforeCurrentWord: String(commandLine[..<currentStart])
        )
    }

    private func completeGitSubcommand(prefix: String, workingDirectory: String, limit: Int) -> [CompletionMatch]? {
        let commandLine = prefix.trimmingCharacters(in: .newlines)
        guard commandLine.hasPrefix("git ") else { return nil }
        guard let context = shellWordContext(for: commandLine), context.command == "git" else { return nil }

        let parts = commandLine.split(separator: " ", omittingEmptySubsequences: true)
        let lastWordComplete = commandLine.last?.isWhitespace == true
        guard parts.count >= 2 else {
            return completeGitSubcommands(partial: "", prefix: "git ", limit: limit)
        }
        let subcommand = String(parts[1])
        if parts.count == 2, !lastWordComplete, !gitSubcommands.contains(subcommand) {
            return completeGitSubcommands(partial: context.currentWord, prefix: context.prefixBeforeCurrentWord, limit: limit)
        }
        let argumentPartial = parts.count == 2 && !lastWordComplete ? "" : context.currentWord
        let argumentPrefix = parts.count == 2 && !lastWordComplete ? commandLine + " " : context.prefixBeforeCurrentWord
        let workingDirURL = URL(fileURLWithPath: workingDirectory)

        switch subcommand {
        case "checkout", "switch", "co":
            return completeGitBranches(partial: argumentPartial, prefix: argumentPrefix, workingDirectory: workingDirURL, sectionTitle: "Git Branches", limit: limit)
        case "add":
            return completeGitFiles(partial: argumentPartial, prefix: argumentPrefix, workingDirectory: workingDirURL, sectionTitle: "Git Files", limit: limit)
        case "diff", "show":
            var results = completeGitBranches(partial: argumentPartial, prefix: argumentPrefix, workingDirectory: workingDirURL, sectionTitle: "Git Branches", limit: limit / 2)
            results += completeGitFiles(partial: argumentPartial, prefix: argumentPrefix, workingDirectory: workingDirURL, sectionTitle: "Git Modified Files", limit: limit / 2)
            return results.isEmpty ? nil : results
        case "merge", "rebase":
            return completeGitBranches(partial: argumentPartial, prefix: argumentPrefix, workingDirectory: workingDirURL, sectionTitle: "Git Branches", limit: limit)
        case "push", "pull", "fetch":
            return completeGitRemotes(partial: argumentPartial, prefix: argumentPrefix, workingDirectory: workingDirURL, limit: limit)
        case "branch":
            if parts.count >= 3, ["-d", "-D"].contains(parts[2]) {
                return completeGitBranches(partial: argumentPartial, prefix: argumentPrefix, workingDirectory: workingDirURL, sectionTitle: "Git Branches", limit: limit)
            }
            return nil
        default:
            return nil
        }
    }

    private var gitSubcommands: [String] {
        [
            "add", "branch", "checkout", "clone", "commit", "diff", "fetch",
            "log", "merge", "pull", "push", "rebase", "restore", "show",
            "status", "switch",
        ]
    }

    private func completeGitSubcommands(partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        gitSubcommands
            .filter { partial.isEmpty || $0.hasPrefix(partial) }
            .prefix(limit)
            .map { command in
                CompletionMatch(
                    command: prefix + command,
                    subtitle: "Git subcommand",
                    sectionTitle: "Git Commands",
                    systemImage: "arrow.triangle.branch"
                )
            }
    }

    private func completeGitBranches(partial: String, prefix: String, workingDirectory: URL, sectionTitle: String, limit: Int) -> [CompletionMatch] {
        guard let output = runGit(args: ["branch", "--format=%(refname:short)"], workingDirectory: workingDirectory) else {
            return []
        }
        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("* ") }
            .filter { partial.isEmpty || $0.localizedCaseInsensitiveContains(partial) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .prefix(limit)
            .map { branch in
                CompletionMatch(
                    command: prefix + shellEscaped(branch),
                    subtitle: "Git branch",
                    sectionTitle: sectionTitle,
                    systemImage: "arrow.triangle.branch"
                )
            }
    }

    private func completeGitFiles(partial: String, prefix: String, workingDirectory: URL, sectionTitle: String, limit: Int) -> [CompletionMatch] {
        guard let output = runGit(args: ["ls-files", "--modified", "--others", "--exclude-standard"], workingDirectory: workingDirectory) else {
            return []
        }
        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { partial.isEmpty || $0.localizedCaseInsensitiveContains(partial) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .prefix(limit)
            .map { file in
                let isDirectory = file.hasSuffix("/")
                return CompletionMatch(
                    command: prefix + shellEscaped(file),
                    subtitle: "Modified file",
                    sectionTitle: sectionTitle,
                    systemImage: isDirectory ? "folder" : "doc"
                )
            }
    }

    private func completeGitRemotes(partial: String, prefix: String, workingDirectory: URL, limit: Int) -> [CompletionMatch] {
        guard let output = runGit(args: ["remote"], workingDirectory: workingDirectory) else {
            return []
        }
        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { partial.isEmpty || $0.localizedCaseInsensitiveContains(partial) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .prefix(limit)
            .map { remote in
                CompletionMatch(
                    command: prefix + shellEscaped(remote),
                    subtitle: "Git remote",
                    sectionTitle: "Git Remotes",
                    systemImage: "cloud"
                )
            }
    }

    private func runGit(args: [String], workingDirectory: URL, timeout: TimeInterval = 3) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = workingDirectory
        process.environment = ["PATH": "/usr/bin:/usr/local/bin:/opt/homebrew/bin"]
        process.qualityOfService = .userInitiated

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Date() >= deadline {
                process.terminate()
                return nil
            }
            Thread.sleep(forTimeInterval: 0.02)
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Docker completion

    private func completeDockerSubcommand(prefix: String, limit: Int) -> [CompletionMatch]? {
        let commandLine = prefix.trimmingCharacters(in: .newlines)
        guard commandLine.hasPrefix("docker ") else { return nil }
        guard let context = shellWordContext(for: commandLine), context.command == "docker" else { return nil }

        let parts = commandLine.split(separator: " ", omittingEmptySubsequences: true)
        let lastWordComplete = commandLine.last?.isWhitespace == true
        guard parts.count >= 2 else {
            return completeDockerSubcommands(partial: "", prefix: "docker ", limit: limit)
        }
        let subcommand = String(parts[1])
        if parts.count == 2, !lastWordComplete, !dockerSubcommands.contains(subcommand) {
            return completeDockerSubcommands(partial: context.currentWord, prefix: context.prefixBeforeCurrentWord, limit: limit)
        }
        let partial = parts.count == 2 && !lastWordComplete ? "" : context.currentWord
        let completionPrefix = parts.count == 2 && !lastWordComplete ? commandLine + " " : context.prefixBeforeCurrentWord

        switch subcommand {
        case "stop", "start", "restart", "rm", "exec", "inspect", "logs", "attach", "kill", "pause", "unpause":
            return completeDockerContainers(partial: partial, prefix: completionPrefix, all: false, limit: limit)
        case "ps":
            // docker ps --filter or flag completion — not handled yet
            return nil
        case "container":
            guard parts.count >= 3 else {
                return completeDockerContainerSubcommands(partial: partial, prefix: completionPrefix, limit: limit)
            }
            let containerCommand = String(parts[2])
            if parts.count == 3, !lastWordComplete, !dockerContainerSubcommands.contains(containerCommand) {
                return completeDockerContainerSubcommands(partial: context.currentWord, prefix: context.prefixBeforeCurrentWord, limit: limit)
            }
            if dockerContainerSubcommands.contains(containerCommand) {
                let nestedPartial = parts.count == 3 && !lastWordComplete ? "" : context.currentWord
                let nestedPrefix = parts.count == 3 && !lastWordComplete ? commandLine + " " : context.prefixBeforeCurrentWord
                return completeDockerContainers(partial: nestedPartial, prefix: nestedPrefix, all: false, limit: limit)
            }
            return nil
        case "rmi":
            return completeDockerImages(partial: partial, prefix: completionPrefix, limit: limit)
        case "compose":
            if parts.count == 2 {
                return completeDockerComposeSubcommands(partial: partial, prefix: completionPrefix, limit: limit)
            }
            return nil
        case "run":
            // docker run IMAGE — complete images for the next argument
            return completeDockerImages(partial: partial, prefix: completionPrefix, limit: limit)
        default:
            return nil
        }
    }

    private var dockerSubcommands: [String] {
        [
            "attach", "build", "compose", "container", "exec", "images",
            "inspect", "kill", "logs", "pause", "ps", "pull", "push",
            "restart", "rm", "rmi", "run", "start", "stop", "unpause",
        ]
    }

    private func completeDockerSubcommands(partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        dockerSubcommands
            .filter { partial.isEmpty || $0.hasPrefix(partial) }
            .prefix(limit)
            .map { command in
                CompletionMatch(
                    command: prefix + command,
                    subtitle: "Docker subcommand",
                    sectionTitle: "Docker Commands",
                    systemImage: "shippingbox"
                )
            }
    }

    private var dockerContainerSubcommands: [String] {
        ["exec", "inspect", "logs", "restart", "rm", "start", "stop"]
    }

    private func completeDockerContainerSubcommands(partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        dockerContainerSubcommands
            .filter { partial.isEmpty || $0.hasPrefix(partial) }
            .prefix(limit)
            .map { command in
                CompletionMatch(
                    command: prefix + command,
                    subtitle: "Container subcommand",
                    sectionTitle: "Docker Containers",
                    systemImage: "shippingbox"
                )
            }
    }

    private func completeDockerContainers(partial: String, prefix: String, all: Bool, limit: Int) -> [CompletionMatch] {
        var args = ["ps", "--format={{.ID}} {{.Names}}"]
        if all { args.append("-a") }
        guard let output = runDocker(args: args) else { return [] }

        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { partial.isEmpty || $0.localizedCaseInsensitiveContains(partial) }
            .prefix(limit)
            .map { line in
                let parts = line.split(separator: " ", maxSplits: 1)
                let id = String(parts.first ?? "")
                let name = parts.count > 1 ? String(parts[1]) : id
                let display = name == id ? String(id.prefix(12)) : name
                return CompletionMatch(
                    command: prefix + shellEscaped(display),
                    subtitle: "Container (\(String(id.prefix(12))))",
                    sectionTitle: "Docker Containers",
                    systemImage: "shippingbox"
                )
            }
    }

    private func completeDockerImages(partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        guard let output = runDocker(args: ["images", "--format={{.Repository}}:{{.Tag}}"]) else { return [] }

        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.contains("<none>") }
            .filter { partial.isEmpty || $0.localizedCaseInsensitiveContains(partial) }
            .prefix(limit)
            .map { image in
                CompletionMatch(
                    command: prefix + shellEscaped(image),
                    subtitle: "Docker image",
                    sectionTitle: "Docker Images",
                    systemImage: "archivebox"
                )
            }
    }

    private func completeDockerComposeSubcommands(partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        let subcommands = [
            "build", "config", "create", "down", "events", "exec", "images",
            "kill", "logs", "ls", "pause", "port", "ps", "pull", "push",
            "restart", "rm", "run", "start", "stop", "top", "unpause", "up",
            "version", "wait", "watch",
        ]
        return subcommands
            .filter { partial.isEmpty || $0.hasPrefix(partial) }
            .prefix(limit)
            .map { cmd in
                CompletionMatch(
                    command: prefix + cmd,
                    subtitle: "Compose subcommand",
                    sectionTitle: "Docker Compose",
                    systemImage: "rectangle.stack"
                )
            }
    }

    private func runDocker(args: [String], timeout: TimeInterval = 3) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
        process.arguments = args
        process.environment = ["PATH": "/usr/bin:/usr/local/bin:/opt/homebrew/bin"]
        process.qualityOfService = .userInitiated

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            // Try /opt/homebrew/bin/docker for Apple Silicon
            let fallback = Process()
            fallback.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/docker")
            fallback.arguments = args
            fallback.environment = ["PATH": "/usr/bin:/usr/local/bin:/opt/homebrew/bin"]
            fallback.qualityOfService = .userInitiated
            let fallbackPipe = Pipe()
            fallback.standardOutput = fallbackPipe
            fallback.standardError = Pipe()
            do {
                try fallback.run()
            } catch {
                return nil
            }
            return waitAndRead(process: fallback, outputPipe: fallbackPipe, timeout: timeout)
        }

        return waitAndRead(process: process, outputPipe: outputPipe, timeout: timeout)
    }

    private func waitAndRead(process: Process, outputPipe: Pipe, timeout: TimeInterval) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Date() >= deadline {
                process.terminate()
                return nil
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        guard process.terminationStatus == 0 else { return nil }
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    // MARK: - kubectl completion

    private func completeKubectlSubcommand(prefix: String, limit: Int) -> [CompletionMatch]? {
        let commandLine = prefix.trimmingCharacters(in: .newlines)
        let commandName: String
        if commandLine.hasPrefix("kubectl ") {
            commandName = "kubectl"
        } else if commandLine.hasPrefix("k ") {
            commandName = "k"
        } else {
            return nil
        }

        let parts = commandLine.split(separator: " ", omittingEmptySubsequences: true)
        let lastWordComplete = commandLine.last?.isWhitespace == true
        guard let context = shellWordContext(for: commandLine) else { return nil }
        guard parts.count >= 2 else {
            return completeKubectlSubcommands(partial: "", prefix: "\(commandName) ", limit: limit)
        }
        let subcommand = String(parts[1])
        if parts.count == 2, !lastWordComplete, !kubectlSubcommands.contains(subcommand) {
            return completeKubectlSubcommands(partial: context.currentWord, prefix: context.prefixBeforeCurrentWord, limit: limit)
        }
        let partial = parts.count == 2 && !lastWordComplete ? "" : context.currentWord
        let completionPrefix = parts.count == 2 && !lastWordComplete ? commandLine + " " : context.prefixBeforeCurrentWord

        switch subcommand {
        case "get", "describe", "delete", "edit", "patch":
            if parts.count == 2 || (parts.count == 3 && !lastWordComplete) {
                return completeKubectlResourceTypes(partial: partial, prefix: completionPrefix, limit: limit)
            }
            let resourceType = String(parts[2])
            return completeKubectlResources(resourceType: resourceType, partial: partial, prefix: completionPrefix, limit: limit)
        case "logs", "exec", "port-forward", "attach", "cp":
            return completeKubectlResources(resourceType: "pods", partial: partial, prefix: completionPrefix, limit: limit)
        case "apply", "create", "replace":
            return nil
        case "config":
            guard parts.count >= 3 else {
                return completeKubectlConfigSubcommands(partial: partial, prefix: completionPrefix, limit: limit)
            }
            let configCommand = String(parts[2])
            if parts.count == 3, !lastWordComplete, !kubectlConfigSubcommands.contains(configCommand) {
                return completeKubectlConfigSubcommands(partial: context.currentWord, prefix: context.prefixBeforeCurrentWord, limit: limit)
            }
            if kubectlConfigSubcommands.contains(configCommand) {
                let nestedPartial = parts.count == 3 && !lastWordComplete ? "" : context.currentWord
                let nestedPrefix = parts.count == 3 && !lastWordComplete ? commandLine + " " : context.prefixBeforeCurrentWord
                return completeKubectlContexts(partial: nestedPartial, prefix: nestedPrefix, limit: limit)
            }
            return nil
        case "rollout":
            guard parts.count >= 3 else {
                return completeKubectlRolloutSubcommands(partial: partial, prefix: completionPrefix, limit: limit)
            }
            let rolloutCommand = String(parts[2])
            if parts.count == 3, !lastWordComplete, !kubectlRolloutSubcommands.contains(rolloutCommand) {
                return completeKubectlRolloutSubcommands(partial: context.currentWord, prefix: context.prefixBeforeCurrentWord, limit: limit)
            }
            if kubectlRolloutSubcommands.contains(rolloutCommand) {
                let nestedPartial = parts.count == 3 && !lastWordComplete ? "" : context.currentWord
                let nestedPrefix = parts.count == 3 && !lastWordComplete ? commandLine + " " : context.prefixBeforeCurrentWord
                return completeKubectlResources(resourceType: "deployments", partial: nestedPartial, prefix: nestedPrefix, limit: limit)
            }
            return nil
        case "scale":
            return completeKubectlResources(resourceType: "deployments", partial: partial, prefix: completionPrefix, limit: limit)
        case "-n", "--namespace":
            return completeKubectlNamespaces(partial: partial, prefix: completionPrefix, limit: limit)
        default:
            return nil
        }
    }

    private var kubectlSubcommands: [String] {
        [
            "apply", "attach", "config", "cp", "create", "delete",
            "describe", "edit", "exec", "get", "logs", "patch",
            "port-forward", "replace", "rollout", "scale",
        ]
    }

    private func completeKubectlSubcommands(partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        kubectlSubcommands
            .filter { partial.isEmpty || $0.hasPrefix(partial) }
            .prefix(limit)
            .map { command in
                CompletionMatch(
                    command: prefix + command,
                    subtitle: "kubectl subcommand",
                    sectionTitle: "Kubernetes Commands",
                    systemImage: "cube"
                )
            }
    }

    private var kubectlConfigSubcommands: [String] {
        ["delete-context", "rename-context", "set-context", "use-context"]
    }

    private func completeKubectlConfigSubcommands(partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        kubectlConfigSubcommands
            .filter { partial.isEmpty || $0.hasPrefix(partial) }
            .prefix(limit)
            .map { command in
                CompletionMatch(
                    command: prefix + command,
                    subtitle: "kubectl config subcommand",
                    sectionTitle: "Kubernetes Config",
                    systemImage: "gearshape"
                )
            }
    }

    private var kubectlRolloutSubcommands: [String] {
        ["history", "pause", "restart", "resume", "status", "undo"]
    }

    private func completeKubectlRolloutSubcommands(partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        kubectlRolloutSubcommands
            .filter { partial.isEmpty || $0.hasPrefix(partial) }
            .prefix(limit)
            .map { command in
                CompletionMatch(
                    command: prefix + command,
                    subtitle: "kubectl rollout subcommand",
                    sectionTitle: "Kubernetes Rollout",
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }
    }

    private func completeKubectlResourceTypes(partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        let resourceTypes = [
            "pods", "services", "deployments", "replicasets", "statefulsets",
            "daemonsets", "jobs", "cronjobs", "configmaps", "secrets",
            "ingresses", "namespaces", "nodes", "persistentvolumeclaims",
            "persistentvolumes", "serviceaccounts", "roles", "rolebindings",
            "clusterroles", "clusterrolebindings", "events", "endpoints",
            "networkpolicies", "horizontalpodautoscalers",
        ]
        return resourceTypes
            .filter { partial.isEmpty || $0.hasPrefix(partial) }
            .prefix(limit)
            .map { resource in
                CompletionMatch(
                    command: prefix + resource,
                    subtitle: "Resource type",
                    sectionTitle: "Kubernetes Resources",
                    systemImage: "cube"
                )
            }
    }

    private func completeKubectlResources(resourceType: String, partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        guard let output = runCLI(
            paths: ["/usr/local/bin/kubectl", "/opt/homebrew/bin/kubectl"],
            args: ["get", resourceType, "--no-headers", "-o", "custom-columns=NAME:.metadata.name"]
        ) else { return [] }

        let sectionTitle: String
        switch resourceType {
        case "pods": sectionTitle = "Pods"
        case "services", "svc": sectionTitle = "Services"
        case "deployments", "deploy": sectionTitle = "Deployments"
        case "namespaces", "ns": sectionTitle = "Namespaces"
        default: sectionTitle = "Kubernetes \(resourceType.capitalized)"
        }

        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { partial.isEmpty || $0.localizedCaseInsensitiveContains(partial) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .prefix(limit)
            .map { name in
                CompletionMatch(
                    command: prefix + shellEscaped(name),
                    subtitle: resourceType.hasSuffix("s") ? String(resourceType.dropLast()) : resourceType,
                    sectionTitle: sectionTitle,
                    systemImage: "cube"
                )
            }
    }

    private func completeKubectlContexts(partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        guard let output = runCLI(
            paths: ["/usr/local/bin/kubectl", "/opt/homebrew/bin/kubectl"],
            args: ["config", "get-contexts", "--no-headers", "-o", "name"]
        ) else { return [] }

        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { partial.isEmpty || $0.localizedCaseInsensitiveContains(partial) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .prefix(limit)
            .map { ctx in
                CompletionMatch(
                    command: prefix + shellEscaped(ctx),
                    subtitle: "Context",
                    sectionTitle: "Kubernetes Contexts",
                    systemImage: "server.rack"
                )
            }
    }

    private func completeKubectlNamespaces(partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        return completeKubectlResources(resourceType: "namespaces", partial: partial, prefix: prefix, limit: limit)
    }

    // MARK: - gh (GitHub CLI) completion

    private func completeGhSubcommand(prefix: String, workingDirectory: String, limit: Int) -> [CompletionMatch]? {
        let commandLine = prefix.trimmingCharacters(in: .newlines)
        guard commandLine.hasPrefix("gh ") else { return nil }

        let parts = commandLine.split(separator: " ", omittingEmptySubsequences: true)
        let lastWordComplete = commandLine.last?.isWhitespace == true
        guard let context = shellWordContext(for: commandLine) else { return nil }
        guard parts.count >= 2 else {
            return completeGhTopLevelSubcommands(partial: "", prefix: "gh ", limit: limit)
        }
        let subcommand = String(parts[1])
        if parts.count == 2, !lastWordComplete, !ghTopLevelSubcommands.contains(subcommand) {
            return completeGhTopLevelSubcommands(partial: context.currentWord, prefix: context.prefixBeforeCurrentWord, limit: limit)
        }
        let partial = parts.count == 2 && !lastWordComplete ? "" : context.currentWord
        let completionPrefix = parts.count == 2 && !lastWordComplete ? commandLine + " " : context.prefixBeforeCurrentWord
        let workingDirURL = URL(fileURLWithPath: workingDirectory)

        switch subcommand {
        case "pr":
            if parts.count == 2 {
                return completeGhPrSubcommands(partial: partial, prefix: completionPrefix, limit: limit)
            }
            let prCommand = String(parts[2])
            if parts.count == 3, !lastWordComplete, !ghPrSubcommands.contains(prCommand) {
                return completeGhPrSubcommands(partial: context.currentWord, prefix: context.prefixBeforeCurrentWord, limit: limit)
            }
            if ghPrNumberSubcommands.contains(prCommand) {
                let nestedPartial = parts.count == 3 && !lastWordComplete ? "" : context.currentWord
                let nestedPrefix = parts.count == 3 && !lastWordComplete ? commandLine + " " : context.prefixBeforeCurrentWord
                return completeGhPrNumbers(partial: nestedPartial, prefix: nestedPrefix, workingDirectory: workingDirURL, limit: limit)
            }
            return nil
        case "issue":
            if parts.count == 2 {
                return completeGhIssueSubcommands(partial: partial, prefix: completionPrefix, limit: limit)
            }
            let issueCommand = String(parts[2])
            if parts.count == 3, !lastWordComplete, !ghIssueSubcommands.contains(issueCommand) {
                return completeGhIssueSubcommands(partial: context.currentWord, prefix: context.prefixBeforeCurrentWord, limit: limit)
            }
            if ghIssueNumberSubcommands.contains(issueCommand) {
                let nestedPartial = parts.count == 3 && !lastWordComplete ? "" : context.currentWord
                let nestedPrefix = parts.count == 3 && !lastWordComplete ? commandLine + " " : context.prefixBeforeCurrentWord
                return completeGhIssueNumbers(partial: nestedPartial, prefix: nestedPrefix, workingDirectory: workingDirURL, limit: limit)
            }
            return nil
        case "repo":
            if parts.count == 2 || (parts.count == 3 && !lastWordComplete) {
                return completeGhRepoSubcommands(partial: partial, prefix: completionPrefix, limit: limit)
            }
            return nil
        case "run":
            if parts.count == 2 {
                return completeGhRunSubcommands(partial: partial, prefix: completionPrefix, limit: limit)
            }
            let runCommand = String(parts[2])
            if parts.count == 3, !lastWordComplete, !ghRunSubcommands.contains(runCommand) {
                return completeGhRunSubcommands(partial: context.currentWord, prefix: context.prefixBeforeCurrentWord, limit: limit)
            }
            if ghRunIDSubcommands.contains(runCommand) {
                let nestedPartial = parts.count == 3 && !lastWordComplete ? "" : context.currentWord
                let nestedPrefix = parts.count == 3 && !lastWordComplete ? commandLine + " " : context.prefixBeforeCurrentWord
                return completeGhRunIds(partial: nestedPartial, prefix: nestedPrefix, workingDirectory: workingDirURL, limit: limit)
            }
            return nil
        default:
            return []
        }
    }

    private var ghTopLevelSubcommands: [String] {
        [
            "alias", "api", "auth", "browse", "codespace", "completion",
            "config", "extension", "gist", "gpg-key", "issue", "label",
            "pr", "release", "repo", "run", "search", "secret",
            "ssh-key", "status", "workflow",
        ]
    }

    private func completeGhTopLevelSubcommands(partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        ghTopLevelSubcommands
            .filter { partial.isEmpty || $0.hasPrefix(partial) }
            .prefix(limit)
            .map { command in
                CompletionMatch(
                    command: prefix + command,
                    subtitle: "GitHub CLI command",
                    sectionTitle: "GitHub Commands",
                    systemImage: "chevron.left.forwardslash.chevron.right"
                )
            }
    }

    private var ghPrSubcommands: [String] {
        [
            "checkout", "close", "create", "diff", "edit", "list", "merge",
            "ready", "reopen", "review", "status", "view",
        ]
    }

    private var ghPrNumberSubcommands: [String] {
        ["checkout", "close", "diff", "edit", "merge", "ready", "reopen", "review", "view"]
    }

    private func completeGhPrSubcommands(partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        ghPrSubcommands
            .filter { partial.isEmpty || $0.hasPrefix(partial) }
            .prefix(limit)
            .map { cmd in
                CompletionMatch(
                    command: prefix + cmd,
                    subtitle: "PR subcommand",
                    sectionTitle: "GitHub PR",
                    systemImage: "arrow.triangle.pull"
                )
            }
    }

    private func completeGhPrNumbers(partial: String, prefix: String, workingDirectory: URL, limit: Int) -> [CompletionMatch] {
        guard let output = runCLI(
            paths: ["/usr/local/bin/gh", "/opt/homebrew/bin/gh"],
            args: ["pr", "list", "--limit", "\(limit)", "--json", "number,title,headRefName", "--jq", ".[] | \"\\(.number) \\(.headRefName) \\(.title)\""],
            workingDirectory: workingDirectory
        ) else { return [] }

        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { partial.isEmpty || $0.localizedCaseInsensitiveContains(partial) }
            .prefix(limit)
            .compactMap { line in
                let lineParts = line.split(separator: " ", maxSplits: 2)
                guard let number = lineParts.first else { return nil as CompletionMatch? }
                let branch = lineParts.count > 1 ? String(lineParts[1]) : ""
                let title = lineParts.count > 2 ? String(lineParts[2]) : ""
                let subtitle = title.isEmpty ? branch : "\(branch) — \(title)"
                return CompletionMatch(
                    command: prefix + String(number),
                    subtitle: subtitle.isEmpty ? "PR #\(number)" : subtitle,
                    sectionTitle: "Pull Requests",
                    systemImage: "arrow.triangle.pull"
                )
            }
    }

    private var ghIssueSubcommands: [String] {
        [
            "close", "comment", "create", "delete", "edit", "list",
            "pin", "reopen", "status", "transfer", "unpin", "view",
        ]
    }

    private var ghIssueNumberSubcommands: [String] {
        ["close", "comment", "delete", "edit", "pin", "reopen", "unpin", "view"]
    }

    private func completeGhIssueSubcommands(partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        ghIssueSubcommands
            .filter { partial.isEmpty || $0.hasPrefix(partial) }
            .prefix(limit)
            .map { cmd in
                CompletionMatch(
                    command: prefix + cmd,
                    subtitle: "Issue subcommand",
                    sectionTitle: "GitHub Issues",
                    systemImage: "exclamationmark.circle"
                )
            }
    }

    private func completeGhIssueNumbers(partial: String, prefix: String, workingDirectory: URL, limit: Int) -> [CompletionMatch] {
        guard let output = runCLI(
            paths: ["/usr/local/bin/gh", "/opt/homebrew/bin/gh"],
            args: ["issue", "list", "--limit", "\(limit)", "--json", "number,title", "--jq", ".[] | \"\\(.number) \\(.title)\""],
            workingDirectory: workingDirectory
        ) else { return [] }

        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { partial.isEmpty || $0.localizedCaseInsensitiveContains(partial) }
            .prefix(limit)
            .compactMap { line in
                let lineParts = line.split(separator: " ", maxSplits: 1)
                guard let number = lineParts.first else { return nil as CompletionMatch? }
                let title = lineParts.count > 1 ? String(lineParts[1]) : ""
                return CompletionMatch(
                    command: prefix + String(number),
                    subtitle: title.isEmpty ? "Issue #\(number)" : title,
                    sectionTitle: "Issues",
                    systemImage: "exclamationmark.circle"
                )
            }
    }

    private var ghRepoSubcommands: [String] {
        [
            "archive", "clone", "create", "delete", "deploy-key", "edit",
            "fork", "list", "rename", "set-default", "sync", "unarchive", "view",
        ]
    }

    private func completeGhRepoSubcommands(partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        ghRepoSubcommands
            .filter { partial.isEmpty || $0.hasPrefix(partial) }
            .prefix(limit)
            .map { cmd in
                CompletionMatch(
                    command: prefix + cmd,
                    subtitle: "Repo subcommand",
                    sectionTitle: "GitHub Repos",
                    systemImage: "externaldrive"
                )
            }
    }

    private var ghRunSubcommands: [String] {
        ["cancel", "delete", "download", "list", "rerun", "view", "watch"]
    }

    private var ghRunIDSubcommands: [String] {
        ["cancel", "download", "rerun", "view", "watch"]
    }

    private func completeGhRunSubcommands(partial: String, prefix: String, limit: Int) -> [CompletionMatch] {
        ghRunSubcommands
            .filter { partial.isEmpty || $0.hasPrefix(partial) }
            .prefix(limit)
            .map { cmd in
                CompletionMatch(
                    command: prefix + cmd,
                    subtitle: "Run subcommand",
                    sectionTitle: "GitHub Actions",
                    systemImage: "play.circle"
                )
            }
    }

    private func completeGhRunIds(partial: String, prefix: String, workingDirectory: URL, limit: Int) -> [CompletionMatch] {
        guard let output = runCLI(
            paths: ["/usr/local/bin/gh", "/opt/homebrew/bin/gh"],
            args: ["run", "list", "--limit", "\(limit)", "--json", "databaseId,displayTitle,status,headBranch", "--jq", ".[] | \"\\(.databaseId) \\(.status) \\(.headBranch) \\(.displayTitle)\""],
            workingDirectory: workingDirectory
        ) else { return [] }

        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { partial.isEmpty || $0.localizedCaseInsensitiveContains(partial) }
            .prefix(limit)
            .compactMap { line in
                let lineParts = line.split(separator: " ", maxSplits: 3)
                guard let id = lineParts.first else { return nil as CompletionMatch? }
                let status = lineParts.count > 1 ? String(lineParts[1]) : ""
                let branch = lineParts.count > 2 ? String(lineParts[2]) : ""
                let title = lineParts.count > 3 ? String(lineParts[3]) : ""
                let subtitle = [status, branch, title].filter { !$0.isEmpty }.joined(separator: " — ")
                return CompletionMatch(
                    command: prefix + String(id),
                    subtitle: subtitle.isEmpty ? "Run \(id)" : subtitle,
                    sectionTitle: "Workflow Runs",
                    systemImage: "play.circle"
                )
            }
    }

    // MARK: - Shared CLI runner

    private func runCLI(paths: [String], args: [String], workingDirectory: URL? = nil, timeout: TimeInterval = 3) -> String? {
        for path in paths {
            guard FileManager.default.isExecutableFile(atPath: path) else { continue }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = args
            if let workingDirectory { process.currentDirectoryURL = workingDirectory }
            process.environment = ["PATH": "/usr/bin:/usr/local/bin:/opt/homebrew/bin", "HOME": NSHomeDirectory()]
            process.qualityOfService = .userInitiated

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = Pipe()

            do {
                try process.run()
            } catch {
                continue
            }

            return waitAndRead(process: process, outputPipe: outputPipe, timeout: timeout)
        }
        return nil
    }

    func fuzzyScore(_ candidate: String, query: String) -> Int? {
        let candidate = Array(candidate.lowercased())
        let query = Array(query.lowercased())
        guard !query.isEmpty else { return nil }

        var candidateIndex = 0
        var previousMatch = -1
        var score = 0

        for character in query {
            var matchedIndex: Int?
            while candidateIndex < candidate.count {
                if candidate[candidateIndex] == character {
                    matchedIndex = candidateIndex
                    break
                }
                candidateIndex += 1
            }
            guard let matchedIndex else { return nil }

            score += max(1, 40 - matchedIndex)
            if previousMatch + 1 == matchedIndex {
                score += 15
            }
            if matchedIndex == 0 {
                score += 20
            }
            previousMatch = matchedIndex
            candidateIndex = matchedIndex + 1
        }

        if String(candidate).hasPrefix(String(query)) {
            score += 80
        }
        return score
    }
}

struct CompletionMatch: Equatable {
    var command: String
    var subtitle: String
    var sectionTitle: String
    var systemImage: String
}

private struct ZshCompletionEnvironment {
    var entries: [String: CompletionMetadata]
    var completionFunctions: [String: String]
}

private struct ShellWordContext {
    var command: String
    var currentWord: String
    var prefixBeforeCurrentWord: String
}

private struct CompletionMetadata: Equatable {
    var kind: CompletionSourceKind
    var detail: String?

    var subtitle: String {
        if kind == .zshAlias,
           let detail,
           !detail.isEmpty {
            return "alias -> \(detail)"
        }
        return kind.subtitle
    }

    var sectionTitle: String {
        kind.sectionTitle
    }

    var systemImage: String {
        kind.systemImage
    }

    var scoreBoost: Int {
        kind.scoreBoost
    }

    func merged(with other: CompletionMetadata) -> CompletionMetadata {
        kind.rawValue <= other.kind.rawValue ? self : other
    }
}

private enum CompletionSourceKind: Int {
    case zshAlias = 0
    case zshFunction = 1
    case builtin = 2
    case executable = 3

    var subtitle: String {
        switch self {
        case .zshAlias:
            return "zsh alias"
        case .zshFunction:
            return "zsh function"
        case .builtin:
            return "Shell builtin"
        case .executable:
            return "Executable"
        }
    }

    var sectionTitle: String {
        switch self {
        case .zshAlias:
            return "zsh Aliases"
        case .zshFunction:
            return "zsh Functions"
        case .builtin:
            return "Shell Builtins"
        case .executable:
            return "Executables"
        }
    }

    var systemImage: String {
        switch self {
        case .zshAlias:
            return "arrow.triangle.branch"
        case .zshFunction:
            return "function"
        case .builtin:
            return "terminal"
        case .executable:
            return "sparkle.magnifyingglass"
        }
    }

    var scoreBoost: Int {
        switch self {
        case .zshAlias:
            return 45
        case .zshFunction:
            return 25
        case .builtin:
            return 20
        case .executable:
            return 0
        }
    }

}
