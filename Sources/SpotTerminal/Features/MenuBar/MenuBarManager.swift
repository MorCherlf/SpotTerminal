// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import AppKit
import SwiftUI

@MainActor
final class MenuBarManager {
    private let appState: AppState
    private let showQuickPanel: () -> Void
    private let openSettings: () -> Void
    private let showBackgroundSession: (UUID) -> Void
    private let interruptActiveCommand: () -> Void
    private var statusItem: NSStatusItem?
    private var glassPanel: NSPanel?
    private var timer: Timer?

    init(
        appState: AppState,
        showQuickPanel: @escaping () -> Void,
        openSettings: @escaping () -> Void,
        showBackgroundSession: @escaping (UUID) -> Void,
        interruptActiveCommand: @escaping () -> Void
    ) {
        self.appState = appState
        self.showQuickPanel = showQuickPanel
        self.openSettings = openSettings
        self.showBackgroundSession = showBackgroundSession
        self.interruptActiveCommand = interruptActiveCommand
    }

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Spot Terminal")
        item.button?.imagePosition = .imageLeading
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        refresh()

        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(refreshTimerFired),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func refreshTimerFired() {
        refresh()
    }

    private func refresh() {
        guard let statusItem else { return }
        let runningCount = appState.runningBackgroundTaskCount
        statusItem.button?.title = runningCount > 0 ? " \(runningCount)" : ""
    }

    private func makeMenu(runningCount: Int) -> NSMenu {
        let menu = NSMenu()
        let title = runningCount == 0
            ? appState.localized("No running tasks")
            : "\(runningCount) \(runningCount == 1 ? appState.localized("running task") : appState.localized("running tasks"))"
        let titleItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        for taskTitle in appState.runningBackgroundTaskTitles {
            let item = NSMenuItem(title: taskTitle, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: appState.localized("Show Quick Command"), action: #selector(showQuickCommand), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: appState.localized("Settings..."), action: #selector(openSettingsItem), keyEquivalent: ","))

        let interrupt = NSMenuItem(title: appState.localized("Interrupt Active Command"), action: #selector(interruptCommand), keyEquivalent: "")
        interrupt.isEnabled = runningCount > 0
        menu.addItem(interrupt)

        let clearCompleted = NSMenuItem(title: appState.localized("Clear Completed Tasks"), action: #selector(clearCompletedTasks), keyEquivalent: "")
        clearCompleted.isEnabled = appState.completedBackgroundTaskCount > 0
        menu.addItem(clearCompleted)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: appState.localized("Quit Spot Terminal"), action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }
        return menu
    }

    @objc private func showQuickCommand() {
        showQuickPanel()
    }

    @objc private func openSettingsItem() {
        glassPanel?.close()
        openSettings()
    }

    @objc private func interruptCommand() {
        interruptActiveCommand()
    }

    @objc private func clearCompletedTasks() {
        appState.clearCompletedBackgroundSessions()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        if event.type == .rightMouseUp {
            glassPanel?.close()
            statusItem?.menu = makeMenu(runningCount: appState.runningBackgroundTaskCount)
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if glassPanel?.isVisible == true {
            glassPanel?.close()
            return
        }
        showPopover()
    }

    private func showPopover() {
        guard let button = statusItem?.button, let buttonWindow = button.window else { return }

        let hostingController = NSHostingController(
            rootView: MenuBarPopoverView(
                onShowQuickPanel: { [weak self] in
                    self?.glassPanel?.close()
                    self?.showQuickPanel()
                },
                onOpenSettings: { [weak self] in
                    self?.glassPanel?.close()
                    self?.openSettings()
                },
                onOpenTask: { [weak self] id in
                    self?.glassPanel?.close()
                    self?.showBackgroundSession(id)
                },
                onInterrupt: { [weak self] in
                    self?.interruptActiveCommand()
                },
                onClearCompleted: { [weak self] in
                    self?.appState.clearCompletedBackgroundSessions()
                },
                onClose: { [weak self] in
                    self?.glassPanel?.close()
                }
            )
            .environmentObject(appState)
        )
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor

        let size = NSSize(width: 300, height: 340)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingController
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = buttonWindow.convertToScreen(buttonFrameInWindow)
        let origin = NSPoint(
            x: buttonFrameOnScreen.midX - size.width / 2,
            y: buttonFrameOnScreen.minY - size.height - 8
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        glassPanel = panel
        panel.orderFrontRegardless()
    }
}
