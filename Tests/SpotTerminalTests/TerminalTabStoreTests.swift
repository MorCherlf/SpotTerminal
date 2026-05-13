// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import SpotTerminal
import Testing

@Suite("TerminalTabStore")
struct TerminalTabStoreTests {
    @MainActor
    @Test func initialStateHasOneTab() async {
        let store = TerminalTabStore()
        #expect(store.tabs.count == 1)
        #expect(store.activeTab != nil)
        #expect(store.activeTabIndex == 0)
        #expect(store.activeTab?.panes.count == 1)
        #expect(store.activeTab?.activePane != nil)
    }

    @MainActor
    @Test func createTabAddsAndActivates() async {
        let store = TerminalTabStore()
        let originalID = store.activeTabID
        let newTab = store.createTab(title: "New")
        #expect(store.tabs.count == 2)
        #expect(store.activeTabID == newTab.id)
        #expect(store.activeTabID != originalID)
    }

    @MainActor
    @Test func closeTabPreventsDeletingLastTab() async {
        let store = TerminalTabStore()
        let onlyID = store.tabs[0].id
        store.closeTab(id: onlyID)
        #expect(store.tabs.count == 1)
        #expect(store.activeTabID == onlyID)
    }

    @MainActor
    @Test func closeTabActivatesNeighbor() async {
        let store = TerminalTabStore()
        _ = store.tabs[0].id
        let second = store.createTab(title: "Second").id
        let third = store.createTab(title: "Third").id
        store.selectTab(id: second)
        store.closeTab(id: second)
        #expect(store.tabs.count == 2)
        #expect(store.activeTabID == third)
    }

    @MainActor
    @Test func closeLastTabActivatesPrevious() async {
        let store = TerminalTabStore()
        _ = store.createTab(title: "Second")
        let third = store.createTab(title: "Third")
        store.closeTab(id: third.id)
        #expect(store.activeTabID == store.tabs.last?.id)
    }

    @MainActor
    @Test func selectNextTabWraps() async {
        let store = TerminalTabStore()
        let first = store.tabs[0].id
        _ = store.createTab(title: "Second")
        store.selectTab(id: store.tabs.last!.id)
        store.selectNextTab()
        #expect(store.activeTabID == first)
    }

    @MainActor
    @Test func selectPreviousTabWraps() async {
        let store = TerminalTabStore()
        _ = store.createTab(title: "Second")
        store.selectTab(id: store.tabs[0].id)
        store.selectPreviousTab()
        #expect(store.activeTabID == store.tabs.last?.id)
    }

    @MainActor
    @Test func selectTabAtIndexActivatesTab() async {
        let store = TerminalTabStore()
        _ = store.createTab(title: "Second")
        store.selectTab(at: 0)
        #expect(store.activeTabID == store.tabs[0].id)
    }

    @MainActor
    @Test func updateTitleChangesTabTitle() async {
        let store = TerminalTabStore()
        let tabID = store.tabs[0].id
        store.updateTitle("Renamed", for: tabID)
        #expect(store.tabs[0].title == "Renamed")
    }

    @MainActor
    @Test func selectTabIgnoresInvalidID() async {
        let store = TerminalTabStore()
        let original = store.activeTabID
        store.selectTab(id: UUID())
        #expect(store.activeTabID == original)
    }

    @MainActor
    @Test func splitActivePaneAddsAndActivatesPane() async {
        let store = TerminalTabStore()
        let originalPaneID = store.activeTab?.activePaneID
        let newPane = store.splitActivePane(axis: .vertical)
        #expect(newPane != nil)
        #expect(store.activeTab?.panes.count == 2)
        #expect(store.activeTab?.activePaneID == newPane?.id)
        #expect(store.activeTab?.activePaneID != originalPaneID)
        #expect(store.activeTab?.splitAxis == .vertical)
    }

    @MainActor
    @Test func splitActivePaneRecordsHorizontalAxis() async {
        let store = TerminalTabStore()
        _ = store.splitActivePane(axis: .horizontal)
        #expect(store.activeTab?.splitAxis == .horizontal)
    }

    @MainActor
    @Test func closeActivePaneProtectsLastPane() async {
        let store = TerminalTabStore()
        let onlyPaneID = store.activeTab?.activePaneID
        store.closeActivePane()
        #expect(store.activeTab?.panes.count == 1)
        #expect(store.activeTab?.activePaneID == onlyPaneID)
    }

    @MainActor
    @Test func closeActivePaneActivatesNeighbor() async {
        let store = TerminalTabStore()
        let firstPaneID = store.activeTab!.activePaneID!
        let secondPane = store.splitActivePane(axis: .vertical)!
        store.closeActivePane()
        #expect(store.activeTab?.panes.count == 1)
        #expect(store.activeTab?.activePaneID == firstPaneID)
        #expect(store.activeTab?.activePaneID != secondPane.id)
    }

    @MainActor
    @Test func selectPaneIgnoresInvalidID() async {
        let store = TerminalTabStore()
        _ = store.splitActivePane(axis: .vertical)
        let original = store.activeTab?.activePaneID
        store.selectPane(id: UUID())
        #expect(store.activeTab?.activePaneID == original)
    }

    @MainActor
    @Test func selectNextPaneWraps() async {
        let store = TerminalTabStore()
        let firstPaneID = store.activeTab!.activePaneID!
        _ = store.splitActivePane(axis: .vertical)
        store.selectNextPane()
        #expect(store.activeTab?.activePaneID == firstPaneID)
    }

    @MainActor
    @Test func selectPreviousPaneWraps() async {
        let store = TerminalTabStore()
        _ = store.splitActivePane(axis: .vertical)
        let secondPaneID = store.activeTab!.activePaneID!
        store.selectPane(id: store.tabs[0].panes[0].id)
        store.selectPreviousPane()
        #expect(store.activeTab?.activePaneID == secondPaneID)
    }

    @MainActor
    @Test func updatePaneTitleRenamesSinglePaneTab() async {
        let store = TerminalTabStore()
        let tabID = store.tabs[0].id
        let paneID = store.tabs[0].panes[0].id
        store.updatePaneTitle("zsh", paneID: paneID, tabID: tabID)
        #expect(store.tabs[0].panes[0].title == "zsh")
        #expect(store.tabs[0].title == "zsh")
    }

    @MainActor
    @Test func updatePaneTitleKeepsMultiPaneTabTitle() async {
        let store = TerminalTabStore()
        _ = store.splitActivePane(axis: .vertical)
        let tabID = store.tabs[0].id
        let paneID = store.tabs[0].panes[0].id
        store.updatePaneTitle("server", paneID: paneID, tabID: tabID)
        #expect(store.tabs[0].panes[0].title == "server")
        #expect(store.tabs[0].title == "2 panes")
    }

    @MainActor
    @Test func expandedSessionTabCannotSplit() async {
        let store = TerminalTabStore()
        let session = CommandSession(title: "Quick", startShell: false)
        let tab = store.createTabForExpandedSession(session)
        let split = store.splitActivePane(axis: .vertical)
        #expect(split == nil)
        #expect(store.activeTabID == tab.id)
        #expect(store.activeTab?.panes.isEmpty == true)
    }
}
