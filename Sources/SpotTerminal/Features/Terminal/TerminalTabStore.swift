// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Combine
import Foundation

enum TerminalSplitAxis: String, Equatable {
    case vertical
    case horizontal
}

struct TerminalPane: Identifiable, Equatable {
    let id: UUID
    var title: String
    let createdAt: Date

    static func newShellPane(title: String = "Shell") -> TerminalPane {
        TerminalPane(id: UUID(), title: title, createdAt: Date())
    }
}

struct TerminalTab: Identifiable, Equatable {
    let id: UUID
    var title: String
    let createdAt: Date
    var panes: [TerminalPane]
    var activePaneID: UUID?
    var splitAxis: TerminalSplitAxis
    var expandedSession: CommandSession? = nil

    static func == (lhs: TerminalTab, rhs: TerminalTab) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.panes == rhs.panes
            && lhs.activePaneID == rhs.activePaneID
            && lhs.splitAxis == rhs.splitAxis
    }

    static func newShellTab(title: String = "Shell") -> TerminalTab {
        let pane = TerminalPane.newShellPane(title: title)
        return TerminalTab(
            id: UUID(),
            title: title,
            createdAt: Date(),
            panes: [pane],
            activePaneID: pane.id,
            splitAxis: .vertical
        )
    }

    var isExpandedQuickSession: Bool {
        expandedSession != nil
    }

    var activePaneIndex: Int? {
        guard let activePaneID else { return nil }
        return panes.firstIndex { $0.id == activePaneID }
    }

    var activePane: TerminalPane? {
        guard let activePaneID else { return nil }
        return panes.first { $0.id == activePaneID }
    }
}

@MainActor
final class TerminalTabStore: ObservableObject {
    @Published var tabs: [TerminalTab] = []
    @Published var activeTabID: UUID?

    init() {
        let initial = TerminalTab.newShellTab()
        tabs = [initial]
        activeTabID = initial.id
    }

    var activeTab: TerminalTab? {
        guard let activeTabID else { return nil }
        return tabs.first { $0.id == activeTabID }
    }

    var activeTabIndex: Int? {
        guard let activeTabID else { return nil }
        return tabs.firstIndex { $0.id == activeTabID }
    }

    @discardableResult
    func createTab(title: String = "Shell") -> TerminalTab {
        let tab = TerminalTab.newShellTab(title: title)
        tabs.append(tab)
        activeTabID = tab.id
        return tab
    }

    @discardableResult
    func createTabForExpandedSession(_ session: CommandSession) -> TerminalTab {
        let command = session.entries.last?.command ?? "Quick Session"
        let tab = TerminalTab(
            id: UUID(),
            title: command,
            createdAt: Date(),
            panes: [],
            activePaneID: nil,
            splitAxis: .vertical,
            expandedSession: session
        )
        tabs.append(tab)
        activeTabID = tab.id
        return tab
    }

    func closeTab(id: UUID) {
        guard tabs.count > 1 else { return }
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = activeTabID == id
        tabs.remove(at: index)
        if wasActive {
            let newIndex = min(index, tabs.count - 1)
            activeTabID = tabs[newIndex].id
        }
    }

    func selectTab(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
    }

    func selectNextTab() {
        guard let index = activeTabIndex, tabs.count > 1 else { return }
        activeTabID = tabs[(index + 1) % tabs.count].id
    }

    func selectPreviousTab() {
        guard let index = activeTabIndex, tabs.count > 1 else { return }
        activeTabID = tabs[(index - 1 + tabs.count) % tabs.count].id
    }

    func selectTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        activeTabID = tabs[index].id
    }

    func updateTitle(_ title: String, for tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[index].title = title
    }

    func selectPane(id paneID: UUID, in tabID: UUID? = nil) {
        let resolvedTabID = tabID ?? activeTabID
        guard let tabIndex = tabs.firstIndex(where: { $0.id == resolvedTabID }) else { return }
        guard tabs[tabIndex].panes.contains(where: { $0.id == paneID }) else { return }
        tabs[tabIndex].activePaneID = paneID
    }

    @discardableResult
    func splitActivePane(axis: TerminalSplitAxis) -> TerminalPane? {
        guard let tabIndex = activeTabIndex else { return nil }
        guard !tabs[tabIndex].isExpandedQuickSession else { return nil }
        guard !tabs[tabIndex].panes.isEmpty else { return nil }

        let newPane = TerminalPane.newShellPane(title: "Shell")
        let insertIndex = tabs[tabIndex].activePaneIndex.map { $0 + 1 } ?? tabs[tabIndex].panes.count
        tabs[tabIndex].panes.insert(newPane, at: insertIndex)
        tabs[tabIndex].activePaneID = newPane.id
        tabs[tabIndex].splitAxis = axis
        tabs[tabIndex].title = tabTitle(for: tabs[tabIndex])
        return newPane
    }

    func closeActivePane() {
        guard let tabIndex = activeTabIndex else { return }
        guard tabs[tabIndex].panes.count > 1 else { return }
        guard let paneIndex = tabs[tabIndex].activePaneIndex else { return }

        tabs[tabIndex].panes.remove(at: paneIndex)
        let newIndex = min(paneIndex, tabs[tabIndex].panes.count - 1)
        tabs[tabIndex].activePaneID = tabs[tabIndex].panes[newIndex].id
        tabs[tabIndex].title = tabTitle(for: tabs[tabIndex])
    }

    func selectNextPane() {
        guard let tabIndex = activeTabIndex else { return }
        guard let paneIndex = tabs[tabIndex].activePaneIndex, tabs[tabIndex].panes.count > 1 else { return }
        let newIndex = (paneIndex + 1) % tabs[tabIndex].panes.count
        tabs[tabIndex].activePaneID = tabs[tabIndex].panes[newIndex].id
    }

    func selectPreviousPane() {
        guard let tabIndex = activeTabIndex else { return }
        guard let paneIndex = tabs[tabIndex].activePaneIndex, tabs[tabIndex].panes.count > 1 else { return }
        let newIndex = (paneIndex - 1 + tabs[tabIndex].panes.count) % tabs[tabIndex].panes.count
        tabs[tabIndex].activePaneID = tabs[tabIndex].panes[newIndex].id
    }

    func updatePaneTitle(_ title: String, paneID: UUID, tabID: UUID) {
        guard let tabIndex = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        guard let paneIndex = tabs[tabIndex].panes.firstIndex(where: { $0.id == paneID }) else { return }
        tabs[tabIndex].panes[paneIndex].title = title
        if tabs[tabIndex].panes.count == 1 {
            tabs[tabIndex].title = title
        }
    }

    private func tabTitle(for tab: TerminalTab) -> String {
        if tab.panes.count == 1 {
            return tab.panes[0].title
        }
        return "\(tab.panes.count) panes"
    }
}
