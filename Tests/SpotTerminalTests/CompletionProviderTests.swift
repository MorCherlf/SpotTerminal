// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import SpotTerminal
import Testing

struct CompletionProviderTests {

    // MARK: - Fuzzy score

    @Test func exactMatchScoresHighest() {
        let provider = CommandCompletionProvider()
        let exact = provider.fuzzyScore("git", query: "git")
        let partial = provider.fuzzyScore("git", query: "gi")
        let noMatch = provider.fuzzyScore("git", query: "xyz")

        #expect(exact != nil)
        #expect(partial != nil)
        #expect(noMatch == nil)
        #expect(exact! > partial!)
    }

    @Test func prefixMatchScoresHigherThanMidWord() {
        let provider = CommandCompletionProvider()
        let prefixScore = provider.fuzzyScore("checkout", query: "ch")
        let midScore = provider.fuzzyScore("checkout", query: "ck")

        #expect(prefixScore != nil)
        #expect(midScore != nil)
        #expect(prefixScore! > midScore!)
    }

    @Test func consecutiveMatchScoresHigherThanScattered() {
        let provider = CommandCompletionProvider()
        let consecutive = provider.fuzzyScore("checkout", query: "che")
        let scattered = provider.fuzzyScore("checkout", query: "cet")

        #expect(consecutive != nil)
        #expect(scattered != nil)
        #expect(consecutive! > scattered!)
    }

    @Test func firstCharacterMatchGetsBonus() {
        let provider = CommandCompletionProvider()
        let startsWithG = provider.fuzzyScore("git", query: "g")
        let containsG = provider.fuzzyScore("log", query: "g")

        #expect(startsWithG != nil)
        #expect(containsG != nil)
        #expect(startsWithG! > containsG!)
    }

    @Test func emptyQueryReturnsNil() {
        let provider = CommandCompletionProvider()
        #expect(provider.fuzzyScore("any", query: "") == nil)
    }

    @Test func caseInsensitiveMatch() {
        let provider = CommandCompletionProvider()
        let lower = provider.fuzzyScore("Git", query: "git")
        let upper = provider.fuzzyScore("GIT", query: "git")
        let mixed = provider.fuzzyScore("Git", query: "GIT")

        #expect(lower != nil)
        #expect(upper != nil)
        #expect(mixed != nil)
        #expect(lower == upper)
    }

    // MARK: - Completion matching

    @Test func cdCompletionsReturnDirectories() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "cd ",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 10
        )

        #expect(!results.isEmpty)
        for result in results {
            #expect(result.command.hasPrefix("cd "))
            #expect(result.systemImage == "folder")
        }
    }

    @Test func emptyQueryReturnsNoCommandCompletions() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 10
        )
        #expect(results.isEmpty)
    }

    @Test func singleWordQueryReturnsCommandMatches() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "ls",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 10
        )

        #expect(!results.isEmpty)
        #expect(results.contains { $0.command == "ls" })
    }

    // MARK: - Path completion

    @Test func pathCompletionWithSlashReturnsMatches() {
        let provider = CommandCompletionProvider()
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        let results = provider.complete(
            prefix: "ls ~/",
            workingDirectory: homePath,
            limit: 10
        )

        #expect(!results.isEmpty)
        for result in results {
            #expect(result.command.hasPrefix("ls ~/"))
        }
    }

    @Test func trailingSpaceArgumentCompletionPreservesCommandWord() throws {
        let provider = CommandCompletionProvider()
        let directory = try makeTemporaryDirectory()
        try "127.0.0.1".write(to: directory.appendingPathComponent("host-a"), atomically: true, encoding: .utf8)
        try "127.0.0.2".write(to: directory.appendingPathComponent("host-b"), atomically: true, encoding: .utf8)

        let results = provider.complete(
            prefix: "ping ",
            workingDirectory: directory.path,
            limit: 10
        )

        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.command.hasPrefix("ping ") })
        #expect(results.contains { $0.command == "ping host-a" })
    }

    @Test func gitSpaceCompletesSubcommands() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "git ",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 20
        )

        #expect(results.contains { $0.command == "git checkout" })
        #expect(results.contains { $0.command == "git status" })
    }

    @Test func gitPartialCompletesSubcommands() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "git che",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 20
        )

        #expect(results.contains { $0.command == "git checkout" })
    }

    @Test func dockerSpaceCompletesSubcommands() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "docker ",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 20
        )

        #expect(results.contains { $0.command == "docker compose" })
        #expect(results.contains { $0.command == "docker run" })
    }

    @Test func dockerContainerCompletesNestedSubcommands() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "docker container ",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 20
        )

        #expect(results.contains { $0.command == "docker container stop" })
        #expect(results.contains { $0.command == "docker container logs" })
    }

    // MARK: - kubectl completion

    @Test func kubectlSpaceCompletesSubcommands() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "kubectl ",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 20
        )

        #expect(results.contains { $0.command == "kubectl get" })
        #expect(results.contains { $0.command == "kubectl logs" })
    }

    @Test func kubectlExactSubcommandCompletesNextArgument() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "kubectl get",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 30
        )

        #expect(results.contains { $0.command == "kubectl get pods" })
        #expect(results.contains { $0.command == "kubectl get services" })
    }

    @Test func kubectlConfigCompletesNestedSubcommands() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "kubectl config ",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 20
        )

        #expect(results.contains { $0.command == "kubectl config use-context" })
        #expect(results.contains { $0.command == "kubectl config set-context" })
    }

    @Test func kubectlRolloutCompletesNestedSubcommands() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "kubectl rollout ",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 20
        )

        #expect(results.contains { $0.command == "kubectl rollout status" })
        #expect(results.contains { $0.command == "kubectl rollout restart" })
    }

    @Test func kubectlGetCompletesResourceTypes() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "kubectl get ",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 30
        )

        #expect(!results.isEmpty)
        let commands = results.map(\.command)
        #expect(commands.contains { $0.contains("pods") })
        #expect(commands.contains { $0.contains("services") })
        #expect(commands.contains { $0.contains("deployments") })
    }

    @Test func kubectlGetWithPartialFilters() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "kubectl get po",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 10
        )

        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.command.contains("po") })
    }

    @Test func kubectlShortAliasK() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "k get ",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 10
        )

        #expect(!results.isEmpty)
        #expect(results.first?.sectionTitle == "Kubernetes Resources")
    }

    // MARK: - gh completion

    @Test func ghSpaceCompletesTopLevelSubcommands() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "gh ",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 30
        )

        #expect(results.contains { $0.command == "gh pr" })
        #expect(results.contains { $0.command == "gh repo" })
    }

    @Test func ghExactTopLevelCommandCompletesNestedSubcommands() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "gh pr",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 20
        )

        #expect(results.contains { $0.command == "gh pr checkout" })
        #expect(results.contains { $0.command == "gh pr create" })
    }

    @Test func ghPrCompletesSubcommands() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "gh pr ",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 20
        )

        #expect(!results.isEmpty)
        let commands = results.map(\.command)
        #expect(commands.contains { $0.contains("create") })
        #expect(commands.contains { $0.contains("list") })
        #expect(commands.contains { $0.contains("checkout") })
    }

    @Test func ghIssueCompletesSubcommands() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "gh issue ",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 20
        )

        #expect(!results.isEmpty)
        let commands = results.map(\.command)
        #expect(commands.contains { $0.contains("create") })
        #expect(commands.contains { $0.contains("list") })
        #expect(commands.contains { $0.contains("view") })
    }

    @Test func ghRepoCompletesSubcommands() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "gh repo ",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 20
        )

        #expect(!results.isEmpty)
        let commands = results.map(\.command)
        #expect(commands.contains { $0.contains("clone") })
        #expect(commands.contains { $0.contains("create") })
    }

    @Test func ghRunCompletesSubcommands() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "gh run ",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 20
        )

        #expect(!results.isEmpty)
        let commands = results.map(\.command)
        #expect(commands.contains { $0.contains("list") })
        #expect(commands.contains { $0.contains("view") })
    }

    @Test func ghPrSubcommandFiltersByPartial() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "gh pr ch",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 10
        )

        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.command.contains("ch") })
    }

    @Test func ghUnknownSubcommandReturnsEmpty() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "gh nonexistent ",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 10
        )

        #expect(results.isEmpty)
    }

    // MARK: - cd completion

    @Test func cdCompletionSortsAlphabetically() {
        let provider = CommandCompletionProvider()
        let results = provider.complete(
            prefix: "cd ",
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
            limit: 20
        )

        let commands = results.map(\.command)
        #expect(commands == commands.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpotTerminalTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
