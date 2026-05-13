// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import SpotTerminal
import Testing

@MainActor
struct SuggestionEngineTests {

    private func makeSuggestion(_ title: String, section: String = "Test") -> CommandSuggestion {
        CommandSuggestion(
            id: UUID().uuidString,
            title: title,
            subtitle: "test",
            sectionTitle: section,
            systemImage: "terminal",
            kind: .command(title)
        )
    }

    private func makeArchiveSuggestion(_ id: UUID = UUID()) -> CommandSuggestion {
        CommandSuggestion(
            id: UUID().uuidString,
            title: "archived session",
            subtitle: "3 commands",
            sectionTitle: "Archives",
            systemImage: "archivebox",
            kind: .archive(id)
        )
    }

    // MARK: - Selection

    @Test func emptySuggestions() {
        let engine = SuggestionEngine()
        engine.update(suggestions: [])

        #expect(engine.hasSuggestions == false)
        #expect(engine.selectedIndex == nil)
    }

    @Test func moveSelectionDown() {
        let engine = SuggestionEngine()
        let suggestions = (0..<5).map { makeSuggestion("cmd\($0)") }
        engine.update(suggestions: suggestions)

        #expect(engine.moveSelection(delta: 1))
        #expect(engine.selectedIndex == 0)

        #expect(engine.moveSelection(delta: 1))
        #expect(engine.selectedIndex == 1)
    }

    @Test func moveSelectionUp() {
        let engine = SuggestionEngine()
        let suggestions = (0..<5).map { makeSuggestion("cmd\($0)") }
        engine.update(suggestions: suggestions)

        #expect(engine.moveSelection(delta: -1))
        #expect(engine.selectedIndex == 4)
    }

    @Test func moveSelectionWrapsAround() {
        let engine = SuggestionEngine()
        let suggestions = (0..<3).map { makeSuggestion("cmd\($0)") }
        engine.update(suggestions: suggestions)

        for _ in 0..<4 {
            _ = engine.moveSelection(delta: 1)
        }
        #expect(engine.selectedIndex == 0)
    }

    @Test func selectionResetsWhenSuggestionsChangePastBounds() {
        let engine = SuggestionEngine()
        engine.update(suggestions: (0..<5).map { makeSuggestion("cmd\($0)") })
        _ = engine.moveSelection(delta: 1)
        _ = engine.moveSelection(delta: 1)
        #expect(engine.selectedIndex == 1)

        engine.update(suggestions: (0..<1).map { makeSuggestion("cmd\($0)") })
        #expect(engine.selectedIndex == nil)
    }

    // MARK: - Tab cycling

    @Test func tabStartsCycleAndReplacesCommand() {
        let engine = SuggestionEngine()
        let suggestions = [
            makeSuggestion("echo hello"),
            makeSuggestion("echo world"),
        ]
        engine.update(suggestions: suggestions)
        _ = engine.moveSelection(delta: 1)

        let action = engine.handleTab(currentCommand: "")
        guard case .replaceCommand("echo hello") = action else {
            Issue.record("Expected replaceCommand, got \(action)")
            return
        }
    }

    @Test func tabIgnoresArchiveSuggestions() {
        let engine = SuggestionEngine()
        let archiveID = UUID()
        let suggestions = [
            makeArchiveSuggestion(archiveID),
            makeSuggestion("echo hello"),
        ]
        engine.update(suggestions: suggestions)

        let action = engine.handleTab(currentCommand: "")
        guard case .replaceCommand("echo hello") = action else {
            Issue.record("Expected tab to use command suggestion, got \(action)")
            return
        }
        #expect(engine.selectedIndex == 1)
    }

    @Test func tabDoesNothingWhenOnlyArchiveSuggestionsExist() {
        let engine = SuggestionEngine()
        engine.update(suggestions: [makeArchiveSuggestion()])

        let action = engine.handleTab(currentCommand: "")
        #expect(action == .none)
        #expect(engine.selectedIndex == nil)
    }

    @Test func tabAdvancesCycle() {
        let engine = SuggestionEngine()
        let suggestions = [
            makeSuggestion("cmd-a"),
            makeSuggestion("cmd-b"),
            makeSuggestion("cmd-c"),
        ]
        engine.update(suggestions: suggestions)
        _ = engine.moveSelection(delta: 1)

        _ = engine.handleTab(currentCommand: "")
        let action = engine.handleTab(currentCommand: "cmd-a")
        guard case .replaceCommand("cmd-b") = action else {
            Issue.record("Expected replaceCommand(cmd-b), got \(action)")
            return
        }
    }

    @Test func tabCycleKeepsOriginalCandidatesAfterSuggestionsRefresh() {
        let engine = SuggestionEngine()
        let suggestions = [
            makeSuggestion("cd Desktop"),
            makeSuggestion("cd Documents"),
            makeSuggestion("cd Downloads"),
        ]
        engine.update(suggestions: suggestions)

        _ = engine.handleTab(currentCommand: "cd ")
        engine.updateSuggestions(query: "cd Desktop", workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path)

        #expect(engine.suggestions == suggestions)
        #expect(engine.selectedIndex == 0)
    }

    @Test func updateSuggestionsPreservesTrailingSpaceForArgumentCompletion() throws {
        let directory = try makeTemporaryDirectory()
        try "payload".write(to: directory.appendingPathComponent("host-a"), atomically: true, encoding: .utf8)

        let engine = SuggestionEngine()
        engine.updateSuggestions(query: "ping ", workingDirectory: directory.path)

        #expect(!engine.suggestions.isEmpty)
        #expect(engine.suggestions.allSatisfy { suggestion in
            guard case .command(let command) = suggestion.kind else { return false }
            return command.hasPrefix("ping ")
        })
    }

    @Test func enterAfterTabReturnsNoneSoCommandCanSubmit() {
        let engine = SuggestionEngine()
        let suggestions = [
            makeSuggestion("cmd-a"),
            makeSuggestion("cmd-b"),
        ]
        engine.update(suggestions: suggestions)

        _ = engine.handleTab(currentCommand: "")
        let action = engine.handleEnter(currentCommand: "cmd-a")

        #expect(action == .none)
        #expect(engine.selectedIndex == nil)
    }

    @Test func tabCycleResetsWhenCommandDoesNotMatch() {
        let engine = SuggestionEngine()
        let suggestions = [
            makeSuggestion("cmd-a"),
            makeSuggestion("cmd-b"),
        ]
        engine.update(suggestions: suggestions)
        _ = engine.moveSelection(delta: 1)

        _ = engine.handleTab(currentCommand: "")
        engine.normalize(currentCommand: "something-else")

        let action = engine.handleTab(currentCommand: "something-else")
        guard case .replaceCommand("cmd-a") = action else {
            Issue.record("Expected new cycle at cmd-a, got \(action)")
            return
        }
    }

    @Test func tabCycleWrapsAround() {
        let engine = SuggestionEngine()
        let suggestions = [
            makeSuggestion("cmd-a"),
            makeSuggestion("cmd-b"),
        ]
        engine.update(suggestions: suggestions)
        _ = engine.moveSelection(delta: 1)

        _ = engine.handleTab(currentCommand: "")
        _ = engine.handleTab(currentCommand: "cmd-a")

        let action = engine.handleTab(currentCommand: "cmd-b")
        guard case .replaceCommand("cmd-a") = action else {
            Issue.record("Expected wrap to cmd-a, got \(action)")
            return
        }
    }

    // MARK: - Enter

    @Test func enterAppliesSelectedSuggestion() {
        let engine = SuggestionEngine()
        let suggestions = [
            makeSuggestion("cmd-a"),
            makeSuggestion("cmd-b"),
        ]
        engine.update(suggestions: suggestions)
        _ = engine.moveSelection(delta: 1)
        _ = engine.moveSelection(delta: 1)

        let action = engine.handleEnter(currentCommand: "")
        guard case .replaceCommand("cmd-b") = action else {
            Issue.record("Expected replaceCommand(cmd-b), got \(action)")
            return
        }
    }

    @Test func enterAfterManualSelectionStillAppliesSuggestion() {
        let engine = SuggestionEngine()
        let suggestions = [
            makeSuggestion("cmd-a"),
            makeSuggestion("cmd-b"),
        ]
        engine.update(suggestions: suggestions)
        _ = engine.moveSelection(delta: 1)

        let action = engine.handleEnter(currentCommand: "")
        guard case .replaceCommand("cmd-a") = action else {
            Issue.record("Expected replaceCommand(cmd-a), got \(action)")
            return
        }
    }

    @Test func enterWithoutSelectionReturnsNone() {
        let engine = SuggestionEngine()
        engine.update(suggestions: [makeSuggestion("cmd-a")])

        let action = engine.handleEnter(currentCommand: "")
        #expect(action == .none)
    }

    // MARK: - Click

    @Test func clickAppliesSuggestion() {
        let engine = SuggestionEngine()
        engine.update(suggestions: [makeSuggestion("cmd-a"), makeSuggestion("cmd-b")])

        let action = engine.selectSuggestion(at: 1)
        guard case .replaceCommand("cmd-b") = action else {
            Issue.record("Expected replaceCommand(cmd-b), got \(action)")
            return
        }
    }

    @Test func clickResetsTabCycle() {
        let engine = SuggestionEngine()
        let suggestions = [makeSuggestion("cmd-a"), makeSuggestion("cmd-b")]
        engine.update(suggestions: suggestions)
        _ = engine.moveSelection(delta: 1)
        _ = engine.handleTab(currentCommand: "")

        _ = engine.selectSuggestion(at: 1)
        let action = engine.handleTab(currentCommand: "cmd-b")
        guard case .replaceCommand("cmd-a") = action else {
            Issue.record("Expected fresh cycle at cmd-a after click reset, got \(action)")
            return
        }
    }

    // MARK: - Archive action

    @Test func archiveSuggestionReturnsOpenArchive() {
        let engine = SuggestionEngine()
        let archiveID = UUID()
        engine.update(suggestions: [makeArchiveSuggestion(archiveID)])
        _ = engine.moveSelection(delta: 1)

        let action = engine.handleEnter(currentCommand: "")
        guard case .openArchive(archiveID) = action else {
            Issue.record("Expected openArchive, got \(action)")
            return
        }
    }

    // MARK: - Section headers

    @Test func sectionHeaders() {
        let engine = SuggestionEngine()
        engine.update(suggestions: [
            makeSuggestion("a", section: "Section A"),
            makeSuggestion("b", section: "Section A"),
            makeSuggestion("c", section: "Section B"),
        ])

        #expect(engine.sectionHeaderVisibility(at: 0))
        #expect(engine.sectionHeaderVisibility(at: 1) == false)
        #expect(engine.sectionHeaderVisibility(at: 2))
    }

    // MARK: - Reset

    @Test func resetClearsSelection() {
        let engine = SuggestionEngine()
        engine.update(suggestions: [makeSuggestion("cmd-a")])
        _ = engine.moveSelection(delta: 1)
        #expect(engine.selectedIndex == 0)

        engine.reset()
        #expect(engine.selectedIndex == nil)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpotTerminalTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
