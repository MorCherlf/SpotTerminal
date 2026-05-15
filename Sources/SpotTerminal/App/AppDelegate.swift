// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import AppKit
import ApplicationServices
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var appState: AppState?
    private var quickPanelController: QuickPanelController?
    private var hotKeyMonitor: GlobalHotKeyMonitor?
    private var menuBarManager: MenuBarManager?
    private var taskNotifier: TaskNotifier?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var didConfigure = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        PrivacySafeLogger.shared.event("app_launched")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @MainActor
    func configure(with appState: AppState) {
        guard !didConfigure else { return }
        didConfigure = true
        self.appState = appState

        let taskNotifier = TaskNotifier()
        taskNotifier.onOpenSession = { [weak self, weak appState] id in
            guard let appState else { return }
            appState.showBackgroundSession(id: id)
            self?.quickPanelController?.show()
        }
        taskNotifier.requestAuthorizationIfNeeded()
        self.taskNotifier = taskNotifier
        appState.taskNotifier = taskNotifier

        quickPanelController = QuickPanelController(
            appState: appState,
            onExpand: { [weak self] in self?.showTerminalWindow() }
        )
        menuBarManager = MenuBarManager(
            appState: appState,
            showQuickPanel: { [weak self] in self?.quickPanelController?.show() },
            openSettings: { [weak self] in self?.showSettingsWindow() },
            showBackgroundSession: { [weak self] id in
                appState.showBackgroundSession(id: id)
                self?.quickPanelController?.show()
            },
            interruptActiveCommand: { appState.interruptActiveCommand() }
        )
        hotKeyMonitor = GlobalHotKeyMonitor(
            hotKeyProvider: { [weak appState] in appState?.quickPanelHotKey ?? .doubleLeftCommand },
            onDoubleTap: { [weak self] in
                Task { @MainActor in
                    self?.toggleQuickPanel()
                }
            }
        )
        hotKeyMonitor?.start()
        menuBarManager?.start()
        requestAccessibilityPermissionIfNeeded()
    }

    @MainActor
    func toggleQuickPanel() {
        PrivacySafeLogger.shared.event("quick_panel_toggle")
        quickPanelController?.toggle()
    }

    @MainActor
    private func showTerminalWindow() {
        NSApp.activate(ignoringOtherApps: true)

        if let terminalWindow = NSApp.windows.first(where: { window in
            !(window is NSPanel) && window.contentView?.containsSubview(ofType: TerminalWindowMarkerView.self) == true
        }) {
            terminalWindow.makeKeyAndOrderFront(nil)
            return
        }

        if let terminalWindow = NSApp.windows.first(where: { window in
            !(window is NSPanel) && window.title.contains("Spot Terminal")
        }) {
            terminalWindow.makeKeyAndOrderFront(nil)
            return
        }

        if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
            return
        }

        NSApp.sendAction(#selector(NSWindowController.newWindowForTab(_:)), to: nil, from: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: { !($0 is NSPanel) })?.makeKeyAndOrderFront(nil)
        }
    }

    @MainActor
    func showSettingsWindow() {
        guard let appState else { return }
        NSApp.activate(ignoringOtherApps: true)

        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = appState.localized("Settings")
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView().environmentObject(appState))
        settingsWindow = window
        PrivacySafeLogger.shared.event("settings_opened")
        window.makeKeyAndOrderFront(nil)
    }

    @MainActor
    func showAboutPanel() {
        guard let appState else { return }
        NSApp.activate(ignoringOtherApps: true)

        if let aboutWindow {
            aboutWindow.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = appState.localized("About Spot Terminal")
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AboutSpotTerminalView().environmentObject(appState))
        aboutWindow = window
        PrivacySafeLogger.shared.event("about_opened")
        window.makeKeyAndOrderFront(nil)
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let promptKey = "didRequestAccessibilityPermission"
        guard !UserDefaults.standard.bool(forKey: promptKey) else { return }
        UserDefaults.standard.set(true, forKey: promptKey)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

private struct AboutSpotTerminalView: View {
    @EnvironmentObject private var appState: AppState
    private let homepageURL = URL(string: "https://github.com/MorCherlf/SpotTerminal")!

    var body: some View {
        VStack(spacing: 18) {
            appIcon

            VStack(spacing: 6) {
                Text("Spot Terminal")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(appState.localized("Version 1.0.0"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text(appState.localized("Run commands quickly, expand into a full terminal, and keep long-running tasks visible from the menu bar."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)

            Button {
                NSWorkspace.shared.open(homepageURL)
            } label: {
                Label(appState.localized("Project Homepage"), systemImage: "arrow.up.right.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 54)

            Text(appState.localized("Made for macOS"))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(width: 430, height: 360)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var appIcon: some View {
        Image(nsImage: NSImage(named: "SpotTerminal") ?? NSApp.applicationIconImage ?? NSImage())
            .resizable()
            .frame(width: 82, height: 82)
            .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }
}

private extension NSView {
    func containsSubview<T: NSView>(ofType type: T.Type) -> Bool {
        if self is T {
            return true
        }
        return subviews.contains { $0.containsSubview(ofType: type) }
    }
}
