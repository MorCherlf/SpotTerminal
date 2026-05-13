// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import AppKit
import SwiftUI

@main
struct SpotTerminalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup("Spot Terminal") {
            TerminalWindowView()
                .environmentObject(appState)
                .frame(minWidth: 760, minHeight: 460)
                .onAppear {
                    appDelegate.configure(with: appState)
                    if !didCompleteOnboarding {
                        showOnboarding = true
                    }
                }
                .background(TerminalWindowConfigurator(opacity: appState.terminalOpacity))
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(
                        isPresented: $showOnboarding,
                        didCompleteOnboarding: $didCompleteOnboarding
                    )
                    .environmentObject(appState)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(appState.localized("About Spot Terminal")) {
                    appDelegate.showAboutPanel()
                }
            }

            // Keep the system "New Window" (Cmd+N) by NOT replacing .newItem
            CommandGroup(after: .newItem) {
                Button(appState.localized("New Tab")) {
                    appState.tabStore.createTab()
                }
                .keyboardShortcut("t", modifiers: [.command])
            }

            // Override system Close (Cmd+W) to close tab first
            CommandGroup(replacing: .saveItem) {
                Button(appState.localized("Close Tab")) {
                    closeActiveTab()
                }
                .keyboardShortcut("w", modifiers: [.command])
            }

            CommandMenu("Spot Terminal") {
                Button(appState.localized("Show Quick Command")) {
                    appDelegate.toggleQuickPanel()
                }
                .keyboardShortcut(.space, modifiers: [.command, .shift])

                Button(appState.localized("Show Onboarding")) {
                    showOnboarding = true
                }

                Button(appState.localized("Interrupt Current Command")) {
                    appState.interruptActiveCommand()
                }
                .keyboardShortcut(".", modifiers: [.command])
            }

            CommandMenu(appState.localized("Tab")) {
                Button(appState.localized("Next Tab")) {
                    appState.tabStore.selectNextTab()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Button(appState.localized("Previous Tab")) {
                    appState.tabStore.selectPreviousTab()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])

                Divider()

                ForEach(0..<9, id: \.self) { index in
                    Button("\(appState.localized("Select Tab")) \(index + 1)") {
                        appState.tabStore.selectTab(at: index)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [.command])
                    .disabled(appState.tabStore.tabs.count <= index)
                }
            }

            CommandMenu(appState.localized("Pane")) {
                Button(appState.localized("Split Right")) {
                    appState.tabStore.splitActivePane(axis: .vertical)
                }
                .keyboardShortcut("d", modifiers: [.command])

                Button(appState.localized("Split Down")) {
                    appState.tabStore.splitActivePane(axis: .horizontal)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button(appState.localized("Close Pane")) {
                    appState.tabStore.closeActivePane()
                }
                .keyboardShortcut("w", modifiers: [.command, .option])

                Divider()

                Button(appState.localized("Next Pane")) {
                    appState.tabStore.selectNextPane()
                }
                .keyboardShortcut("]", modifiers: [.command, .option])

                Button(appState.localized("Previous Pane")) {
                    appState.tabStore.selectPreviousPane()
                }
                .keyboardShortcut("[", modifiers: [.command, .option])
            }

            CommandMenu(appState.localized("View")) {
                Button(appState.localized("Increase Font Size")) {
                    appState.increaseTerminalFontSize()
                }
                .keyboardShortcut("+", modifiers: [.command])

                Button(appState.localized("Decrease Font Size")) {
                    appState.decreaseTerminalFontSize()
                }
                .keyboardShortcut("-", modifiers: [.command])

                Button(appState.localized("Reset Font Size")) {
                    appState.resetTerminalFontSize()
                }
                .keyboardShortcut("0", modifiers: [.command])
            }

            CommandGroup(after: .textEditing) {
                Button(appState.localized("Find")) {
                    sendTextFinderAction(.showFindInterface)
                }
                .keyboardShortcut("f", modifiers: [.command])

                Button(appState.localized("Find Next")) {
                    sendTextFinderAction(.nextMatch)
                }
                .keyboardShortcut("g", modifiers: [.command])

                Button(appState.localized("Find Previous")) {
                    sendTextFinderAction(.previousMatch)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }

    private func closeActiveTab() {
        let tabStore = appState.tabStore
        if tabStore.tabs.count > 1, let id = tabStore.activeTabID {
            tabStore.closeTab(id: id)
        } else {
            NSApp.keyWindow?.close()
        }
    }

    private func sendTextFinderAction(_ action: NSTextFinder.Action) {
        let item = NSMenuItem()
        item.tag = action.rawValue
        NSApp.sendAction(#selector(NSResponder.performTextFinderAction(_:)), to: nil, from: item)
    }
}

private struct TerminalWindowConfigurator: NSViewRepresentable {
    var opacity: Double

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isOpaque = opacity >= 1.0
            window.backgroundColor = opacity < 1.0
                ? NSColor.black.withAlphaComponent(opacity)
                : NSColor.black
            scheduleTrafficLightAlignment(in: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else { return }
        window.styleMask.insert(.fullSizeContentView)
        window.isOpaque = opacity >= 1.0
        window.backgroundColor = opacity < 1.0
            ? NSColor.black.withAlphaComponent(opacity)
            : NSColor.black
        scheduleTrafficLightAlignment(in: window)
    }

    private func scheduleTrafficLightAlignment(in window: NSWindow) {
        alignTrafficLightButtons(in: window)
        DispatchQueue.main.async {
            alignTrafficLightButtons(in: window)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            alignTrafficLightButtons(in: window)
        }
    }

    private func alignTrafficLightButtons(in window: NSWindow) {
        let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        for buttonType in buttonTypes {
            guard let button = window.standardWindowButton(buttonType) else { continue }
            var frame = button.frame
            frame.origin.y = 4
            button.setFrameOrigin(frame.origin)
        }
    }
}
