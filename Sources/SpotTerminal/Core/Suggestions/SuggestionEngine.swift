// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation

enum SuggestionAction: Equatable {
    case replaceCommand(String)
    case openArchive(UUID)
    case none
}

@MainActor
final class SuggestionEngine: ObservableObject {
    @Published private(set) var suggestions: [CommandSuggestion] = []
    @Published private(set) var selectedIndex: Int?

    var onOpenArchive: ((UUID) -> Void)?

    private let completionProvider = CommandCompletionProvider()
    private var archiveStore: SessionArchiveStore?
    private var tabCycle: TabCompletionCycle?
    private var selectionSource: SelectionSource = .none

    var hasSuggestions: Bool { !suggestions.isEmpty }

    func configure(archiveStore: SessionArchiveStore) {
        self.archiveStore = archiveStore
    }

    func updateSuggestions(query: String, workingDirectory: String) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let completionQuery = query.trimmingCharacters(in: .newlines)
        var results: [CommandSuggestion] = []

        if normalizedQuery.isEmpty {
            if let archiveStore {
                results.append(contentsOf: archiveStore.recentCommands(limit: 5).map { match in
                    CommandSuggestion(
                        id: "recent-\(match.id)",
                        title: match.command,
                        subtitle: "Recent command",
                        sectionTitle: "Recent Commands",
                        systemImage: "clock.arrow.circlepath",
                        kind: .command(match.command)
                    )
                })
                results.append(contentsOf: archiveStore.recentSummaries(limit: 3).map { summary in
                    CommandSuggestion(
                        id: "archive-\(summary.id.uuidString)",
                        title: summary.firstCommand,
                        subtitle: "\(summary.commandCount) command\(summary.commandCount == 1 ? "" : "s") archived",
                        sectionTitle: "Archived Sessions",
                        systemImage: "archivebox",
                        kind: .archive(summary.id)
                    )
                })
            }
        } else {
            let completionLimit = completionQuery.isPathCompletionQuery ? 100 : 20
            results.append(contentsOf: completionProvider.complete(
                prefix: completionQuery,
                workingDirectory: workingDirectory,
                limit: completionLimit
            ).map { completion in
                CommandSuggestion(
                    id: "completion-\(completion.command)-\(completion.sectionTitle)",
                    title: completion.command,
                    subtitle: completion.subtitle,
                    sectionTitle: completion.sectionTitle,
                    systemImage: completion.systemImage,
                    kind: .command(completion.command)
                )
            })
            if let archiveStore {
                results.append(contentsOf: archiveStore.searchCommands(query: normalizedQuery, limit: 3).map { match in
                    CommandSuggestion(
                        id: "history-\(match.id)",
                        title: match.command,
                        subtitle: "History match",
                        sectionTitle: "History Matches",
                        systemImage: "clock",
                        kind: .command(match.command)
                    )
                })
                results.append(contentsOf: archiveStore.searchSummaries(query: normalizedQuery, limit: 2).map { summary in
                    CommandSuggestion(
                        id: "archive-search-\(summary.id.uuidString)",
                        title: summary.firstCommand,
                        subtitle: "\(summary.commandCount) command\(summary.commandCount == 1 ? "" : "s") in archive",
                        sectionTitle: "Archive Matches",
                        systemImage: "archivebox",
                        kind: .archive(summary.id)
                    )
                })
            }
        }

        let nextSuggestions = Array(results.prefix(normalizedQuery.isEmpty ? 8 : 100))
        if let cycle = tabCycle,
           queryMatchesActiveTabCycle(query, cycle: cycle) {
            update(suggestions: cycle.suggestions)
        } else {
            update(suggestions: nextSuggestions)
        }
    }

    func update(suggestions: [CommandSuggestion]) {
        self.suggestions = suggestions
        normalizeSelection()
    }

    func moveSelection(delta: Int) -> Bool {
        guard !suggestions.isEmpty else { return false }
        let count = suggestions.count
        let currentIndex = selectedIndex ?? (delta > 0 ? -1 : count)
        selectedIndex = (currentIndex + delta + count) % count
        selectionSource = .manual
        return true
    }

    func handleTab(currentCommand: String) -> SuggestionAction {
        let tabSuggestions = commandSuggestionsForTab()
        guard !tabSuggestions.isEmpty else { return .none }

        // If we're already in a cycle, try to advance it.
        if let cycle = tabCycle,
           cycle.suggestions.indices.contains(cycle.currentIndex),
           cycle.suggestions.containsCommand(currentCommand) {
            var updated = cycle
            updated.currentIndex = (cycle.currentIndex + 1) % cycle.suggestions.count
            tabCycle = updated
            selectedIndex = originalSuggestionIndex(for: updated.suggestions[updated.currentIndex])
            selectionSource = .tab
            return action(for: cycle.suggestions[updated.currentIndex])
        }

        // Not in a cycle (first press, or command diverged). Start fresh at
        // the selected command suggestion, or the first command suggestion.
        resetTabCycle()
        let index = selectedIndex
            .flatMap { selectedIndex in
                tabSuggestions.firstIndex { originalSuggestionIndex(for: $0) == selectedIndex }
            } ?? 0
        guard tabSuggestions.indices.contains(index) else { return .none }

        startTabCycle(suggestions: tabSuggestions, at: index, baseCommand: currentCommand)
        selectedIndex = originalSuggestionIndex(for: tabSuggestions[index])
        selectionSource = .tab
        return action(for: tabSuggestions[index])
    }

    func handleEnter(currentCommand: String) -> SuggestionAction {
        guard !suggestions.isEmpty else { return .none }
        guard selectionSource == .manual else {
            resetTabCycle()
            selectedIndex = nil
            selectionSource = .none
            return .none
        }
        guard let index = selectedIndex, suggestions.indices.contains(index) else {
            return .none
        }
        resetTabCycle()
        return action(for: suggestions[index])
    }

    func selectSuggestion(at index: Int) -> SuggestionAction {
        guard suggestions.indices.contains(index) else { return .none }
        resetTabCycle()
        selectionSource = .none
        return action(for: suggestions[index])
    }

    func normalize(currentCommand: String) {
        if let cycle = tabCycle {
            if currentCommand == cycle.baseCommand || cycle.suggestions.containsCommand(currentCommand) {
                return
            }
            resetTabCycle()
        }
        if selectionSource == .tab {
            selectedIndex = nil
            selectionSource = .none
        }
        normalizeSelection()
    }

    func reset() {
        selectedIndex = nil
        selectionSource = .none
        resetTabCycle()
    }

    func sectionHeaderVisibility(at index: Int) -> Bool {
        guard suggestions.indices.contains(index) else { return false }
        guard index > 0 else { return true }
        return suggestions[index].sectionTitle != suggestions[index - 1].sectionTitle
    }

    private func action(for suggestion: CommandSuggestion) -> SuggestionAction {
        switch suggestion.kind {
        case .command(let value):
            return .replaceCommand(value)
        case .archive(let id):
            return .openArchive(id)
        }
    }

    private func startTabCycle(suggestions: [CommandSuggestion], at index: Int, baseCommand: String) {
        guard suggestions.indices.contains(index) else { return }
        tabCycle = TabCompletionCycle(
            baseCommand: baseCommand,
            suggestions: suggestions,
            currentIndex: index
        )
    }

    private func normalizeSelection() {
        if suggestions.isEmpty {
            selectedIndex = nil
            selectionSource = .none
            return
        }
        if let index = selectedIndex, suggestions.indices.contains(index) {
            return
        }
        selectedIndex = nil
        selectionSource = .none
    }

    private func resetTabCycle() {
        tabCycle = nil
    }

    private func queryMatchesActiveTabCycle(_ query: String, cycle: TabCompletionCycle) -> Bool {
        query == cycle.baseCommand || cycle.suggestions.containsCommand(query)
    }

    private func commandSuggestionsForTab() -> [CommandSuggestion] {
        suggestions.filter { suggestion in
            if case .command = suggestion.kind {
                return true
            }
            return false
        }
    }

    private func originalSuggestionIndex(for suggestion: CommandSuggestion) -> Int? {
        suggestions.firstIndex { $0.id == suggestion.id }
    }
}

extension String {
    var isPathCompletionQuery: Bool {
        self == "cd"
            || hasPrefix("cd ")
            || contains("/")
            || hasSuffix(" ")
    }
}

private struct TabCompletionCycle {
    var baseCommand: String
    var suggestions: [CommandSuggestion]
    var currentIndex: Int
}

private enum SelectionSource {
    case none
    case manual
    case tab
}

private extension Array where Element == CommandSuggestion {
    func containsCommand(_ command: String) -> Bool {
        contains { suggestion in
            guard case .command(let value) = suggestion.kind else { return false }
            return value == command
        }
    }
}
