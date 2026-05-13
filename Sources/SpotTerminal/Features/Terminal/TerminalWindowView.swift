// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import AppKit
import ApplicationServices
import SwiftUI
import UserNotifications

struct TerminalWindowView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    private var theme: TerminalTheme {
        NamedTerminalTheme.resolve(id: appState.terminalThemeID, colorScheme: colorScheme).ui
    }

    private var tabStore: TerminalTabStore {
        appState.tabStore
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            paneBar
            tabContent
        }
        .background(TerminalWindowMarker())
        .background(theme.background.opacity(appState.terminalOpacity))
        .ignoresSafeArea(.container, edges: [.top, .leading])
    }

    private var tabBar: some View {
        HStack(alignment: .center, spacing: 0) {
            // Leave room for the macOS traffic-light window controls.
            Color.clear
                .frame(width: 78)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 1) {
                    ForEach(tabStore.tabs) { tab in
                        TerminalTabButton(
                            tab: tab,
                            isActive: tab.id == tabStore.activeTabID,
                            tabCount: tabStore.tabs.count,
                            theme: theme,
                            onSelect: { tabStore.selectTab(id: tab.id) },
                            onClose: { tabStore.closeTab(id: tab.id) },
                            onMiddleClick: { tabStore.closeTab(id: tab.id) }
                        )
                    }
                    NewTabButton(theme: theme) {
                        tabStore.createTab()
                    }
                }
                .frame(height: 46, alignment: .center)
            }
            .frame(height: 46)

            splitControls
            Spacer(minLength: 0)
        }
        .frame(height: 46)
        .background(theme.background.opacity(0.6))
    }

    private var splitControls: some View {
        HStack(spacing: 2) {
            Button {
                tabStore.splitActivePane(axis: .vertical)
            } label: {
                Image(systemName: "square.split.2x1")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(tabStore.activeTab?.isExpandedQuickSession == true)
            .help(appState.localized("Split Right"))

            Button {
                tabStore.splitActivePane(axis: .horizontal)
            } label: {
                Image(systemName: "square.split.1x2")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(tabStore.activeTab?.isExpandedQuickSession == true)
            .help(appState.localized("Split Down"))

            Button {
                tabStore.closeActivePane()
            } label: {
                Image(systemName: "rectangle.portrait.slash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled((tabStore.activeTab?.panes.count ?? 0) < 2)
            .help(appState.localized("Close Pane"))
        }
        .padding(.trailing, 8)
    }

    @ViewBuilder
    private var paneBar: some View {
        if let activeTab = tabStore.activeTab, activeTab.panes.count > 1 {
            HStack(spacing: 6) {
                ForEach(activeTab.panes) { pane in
                    Button {
                        tabStore.selectPane(id: pane.id, in: activeTab.id)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: pane.id == activeTab.activePaneID ? "terminal.fill" : "terminal")
                                .font(.system(size: 10, weight: .medium))
                            Text(pane.title)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .foregroundStyle(pane.id == activeTab.activePaneID ? theme.text : theme.secondaryText)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(pane.id == activeTab.activePaneID ? theme.surface : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(appState.localized("Select Pane"))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(theme.background.opacity(0.45))
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        ZStack {
            TerminalTabContainerView(
                activeTabID: tabStore.activeTabID ?? UUID(),
                tabs: tabStore.tabs,
                activePaneID: tabStore.activeTab?.activePaneID,
                themeID: appState.terminalThemeID,
                colorScheme: colorScheme,
                fontName: appState.terminalFontName,
                fontSize: appState.terminalFontSize,
                backgroundOpacity: appState.terminalOpacity,
                onPaneTitleChanged: { tabID, paneID, title in
                    tabStore.updatePaneTitle(title, paneID: paneID, tabID: tabID)
                }
            )

            if let activeTab = tabStore.activeTab, let session = activeTab.expandedSession {
                ExpandedQuickSessionView(
                    session: session,
                    theme: theme,
                    themeID: appState.terminalThemeID,
                    colorScheme: colorScheme
                )
                .id(session.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TerminalWindowMarker: NSViewRepresentable {
    func makeNSView(context: Context) -> TerminalWindowMarkerView {
        TerminalWindowMarkerView()
    }

    func updateNSView(_ nsView: TerminalWindowMarkerView, context: Context) {}
}

final class TerminalWindowMarkerView: NSView {}

private struct NewTabButton: View {
    @EnvironmentObject private var appState: AppState
    let theme: TerminalTheme
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isHovering ? theme.text : theme.secondaryText)
                .frame(width: 42, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovering ? theme.surface.opacity(0.85) : theme.surface.opacity(0.45))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.secondaryText.opacity(isHovering ? 0.35 : 0), lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(appState.localized("New Tab"))
    }
}

// MARK: - Tab Button

private struct TerminalTabButton: View {
    @EnvironmentObject private var appState: AppState
    let tab: TerminalTab
    let isActive: Bool
    let tabCount: Int
    let theme: TerminalTheme
    let onSelect: () -> Void
    let onClose: () -> Void
    let onMiddleClick: () -> Void

    @State private var isHovering = false
    @State private var closeHovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            if tab.expandedSession != nil {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.secondaryText)
            } else if tab.panes.count > 1 {
                Image(systemName: tab.splitAxis == .vertical ? "square.split.2x1" : "square.split.1x2")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.secondaryText)
            }
            Text(tab.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isActive ? theme.text : theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            if tabCount > 1 {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(closeHovering ? theme.text : theme.secondaryText.opacity(isHovering || isActive ? 1 : 0))
                    .frame(width: 20, height: 20, alignment: .center)
                    .background(
                        Circle()
                            .fill(closeHovering ? theme.secondaryText.opacity(0.18) : .clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onClose() }
                    .onHover { closeHovering = $0 }
                    .help(appState.localized("Close Tab"))
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, tabCount > 1 ? 5 : 10)
        .frame(width: 160, height: 32, alignment: .center)
        .padding(.vertical, 0)
        .background(alignment: .center) {
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? theme.surface : (isHovering ? theme.surface.opacity(0.4) : .clear))
                .frame(height: 32)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .gesture(
            TapGesture()
                .onEnded { onSelect() }
        )
        .onHover { isHovering = $0 }
        .overlay(MiddleClickTarget(onMiddleClick: onMiddleClick))
    }
}

private struct MiddleClickTarget: NSViewRepresentable {
    let onMiddleClick: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MiddleClickView {
        let view = MiddleClickView()
        context.coordinator.attach(to: view, onMiddleClick: onMiddleClick)
        return view
    }

    func updateNSView(_ nsView: MiddleClickView, context: Context) {
        context.coordinator.onMiddleClick = onMiddleClick
    }

    static func dismantleNSView(_ nsView: MiddleClickView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        weak var view: MiddleClickView?
        var onMiddleClick: (() -> Void)?
        private var monitor: Any?

        func attach(to view: MiddleClickView, onMiddleClick: @escaping () -> Void) {
            self.view = view
            self.onMiddleClick = onMiddleClick
            monitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { [weak self] event in
                guard let self, let view = self.view, let window = view.window else { return event }
                guard event.window === window, event.buttonNumber == 2 else { return event }
                let point = view.convert(event.locationInWindow, from: nil)
                guard view.bounds.contains(point) else { return event }
                self.onMiddleClick?()
                return nil
            }
        }

        func detach() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }
    }

    final class MiddleClickView: NSView {
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = false
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}

// MARK: - Expanded Quick Session

private struct ExpandedQuickSessionView: View {
    @ObservedObject var session: CommandSession
    var theme: TerminalTheme
    var themeID: String
    var colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 0) {
            CommandTranscriptView(session: session, theme: theme)
                .environment(\.terminalTheme, theme)
                .frame(height: 210)
                .padding(12)
            Divider()
            AttachedShellTerminalView(
                session: session,
                themeKind: .system,
                themeID: themeID,
                colorScheme: colorScheme
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.background)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false
    @State private var showQuickStart = false

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .environmentObject(appState)
                .tabItem { Label(appState.localized("General"), systemImage: "gear") }
            KeyboardSettingsTab()
                .environmentObject(appState)
                .tabItem { Label(appState.localized("Shortcuts"), systemImage: "keyboard") }
            AppearanceSettingsTab()
                .environmentObject(appState)
                .tabItem { Label(appState.localized("Appearance"), systemImage: "paintbrush") }
            LanguageSettingsTab()
                .environmentObject(appState)
                .tabItem { Label(appState.localized("Language"), systemImage: "globe") }
            NotificationSettingsTab()
                .environmentObject(appState)
                .tabItem { Label(appState.localized("Notifications"), systemImage: "bell") }
            UpdatesSettingsTab()
                .environmentObject(appState)
                .tabItem { Label(appState.localized("Updates"), systemImage: "arrow.triangle.2.circlepath") }
            DiagnosticsSettingsTab()
                .environmentObject(appState)
                .tabItem { Label(appState.localized("Diagnostics"), systemImage: "waveform.path.ecg") }
            ArchiveBrowserTab()
                .environmentObject(appState)
                .tabItem { Label(appState.localized("Archive"), systemImage: "archivebox") }
        }
        .frame(width: 620, height: 560)
        .sheet(isPresented: $showQuickStart) {
            OnboardingView(
                isPresented: $showQuickStart,
                didCompleteOnboarding: $didCompleteOnboarding
            )
            .environmentObject(appState)
        }
        .environment(\.openQuickStartGuide, {
            showQuickStart = true
        })
    }
}

private struct OpenQuickStartGuideKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

private extension EnvironmentValues {
    var openQuickStartGuide: () -> Void {
        get { self[OpenQuickStartGuideKey.self] }
        set { self[OpenQuickStartGuideKey.self] = newValue }
    }
}

private struct GeneralSettingsTab: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openQuickStartGuide) private var openQuickStartGuide
    @State private var accessibilityTrusted = AXIsProcessTrusted()
    @State private var showShellDiagnostics = false

    var body: some View {
        Form {
            Section(appState.localized("Permissions")) {
                PermissionStatusRow(
                    title: appState.localized("Accessibility"),
                    isGranted: accessibilityTrusted,
                    grantedText: appState.localized("Allowed"),
                    missingText: appState.localized("Required for global hotkeys")
                )
                Button(appState.localized("Open System Settings")) {
                    openAccessibilitySettings()
                }
                Button(appState.localized("Refresh Status")) {
                    accessibilityTrusted = AXIsProcessTrusted()
                }
            }
            Section(appState.localized("Shell")) {
                LabeledContent(appState.localized("Shell")) {
                    Text(ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh")
                        .font(.system(.body, design: .monospaced))
                }
                Button(appState.localized("Open Shell Diagnostics")) {
                    showShellDiagnostics = true
                }
            }
            Section(appState.localized("Actions")) {
                Button(appState.localized("Quick Start Guide")) {
                    openQuickStartGuide()
                }
                Button(appState.localized("Interrupt Active Command")) {
                    appState.interruptActiveCommand()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            accessibilityTrusted = AXIsProcessTrusted()
        }
        .sheet(isPresented: $showShellDiagnostics) {
            ShellDiagnosticsSheet()
                .environmentObject(appState)
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private struct ShellDiagnosticsSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var diagnostics = SystemDiagnostics.snapshot()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(appState.localized("Shell Diagnostics"))
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(appState.localized("Done")) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(18)
            Divider()
            Form {
                Section(appState.localized("Shell")) {
                    LabeledContent(appState.localized("Shell")) {
                        Text(ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh")
                            .font(.system(.body, design: .monospaced))
                    }
                }
                Section(appState.localized("Diagnostics")) {
                    ForEach(diagnostics) { item in
                        DiagnosticRow(item: item)
                    }
                    Button(appState.localized("Refresh Diagnostics")) {
                        diagnostics = SystemDiagnostics.snapshot()
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 520, height: 420)
    }
}

private struct KeyboardSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section(appState.localized("Quick Panel")) {
                Picker(appState.localized("Quick Panel"), selection: $appState.quickPanelHotKeyID) {
                    ForEach(QuickPanelHotKey.allCases) { hotKey in
                        Text("\(appState.localized(hotKey.title)) (\(hotKey.shortcutText))")
                            .tag(hotKey.rawValue)
                    }
                }
                Text(appState.localized("Requires macOS Accessibility permission."))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Section(appState.localized("Terminal")) {
                ShortcutRow(appState.localized("New Tab"), "⌘T")
                ShortcutRow(appState.localized("Close Tab"), "⌘W")
                ShortcutRow(appState.localized("Select Tab 1-9"), "⌘1...⌘9")
                ShortcutRow(appState.localized("Split Right"), "⌘D")
                ShortcutRow(appState.localized("Split Down"), "⇧⌘D")
                ShortcutRow(appState.localized("Close Pane"), "⌥⌘W")
                ShortcutRow(appState.localized("Next / Previous Pane"), "⌥⌘] / ⌥⌘[")
                ShortcutRow(appState.localized("Next / Previous Tab"), "⇧⌘] / ⇧⌘[")
                ShortcutRow(appState.localized("Increase Font Size"), "⌘+")
                ShortcutRow(appState.localized("Decrease Font Size"), "⌘-")
                ShortcutRow(appState.localized("Reset Font Size"), "⌘0")
            }
        }
        .formStyle(.grouped)
    }
}

private struct LanguageSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section(appState.localized("Language")) {
                Picker(appState.localized("App Language"), selection: $appState.appLanguageID) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title(localized: appState.localized)).tag(language.rawValue)
                    }
                }
                .pickerStyle(.menu)
                Text(appState.localized("Language changes apply immediately for Spot Terminal views."))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct UpdatesSettingsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section(appState.localized("Update Channel")) {
                LabeledContent(appState.localized("Automatic Updates")) {
                    Text(appState.localized("Coming soon"))
                        .foregroundStyle(.secondary)
                }
                Button(appState.localized("Check for Updates")) {}
                    .disabled(true)
                Text(appState.localized("A signed update channel will be added in a future release."))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct DiagnosticsSettingsTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var logURL = PrivacySafeLogger.shared.logURL

    var body: some View {
        Form {
            Section(appState.localized("Privacy-Safe Logs")) {
                Text(appState.localized("Logs include app events, exit codes, durations, and UI state. They do not include commands, terminal output, paths, usernames, hostnames, or device identifiers."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent(appState.localized("Location")) {
                    Text(logURL.path)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
                HStack {
                    Button(appState.localized("Reveal in Finder")) {
                        NSWorkspace.shared.activateFileViewerSelecting([logURL])
                    }
                    Button(appState.localized("Clear Logs")) {
                        PrivacySafeLogger.shared.clear()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct ShortcutRow: View {
    let title: String
    let shortcut: String

    init(_ title: String, _ shortcut: String) {
        self.title = title
        self.shortcut = shortcut
    }

    var body: some View {
        LabeledContent(title) {
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

private struct PermissionStatusRow: View {
    let title: String
    let isGranted: Bool
    let grantedText: String
    let missingText: String

    var body: some View {
        LabeledContent(title) {
            Label(isGranted ? grantedText : missingText, systemImage: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isGranted ? .green : .orange)
        }
    }
}

private struct AppearanceSettingsTab: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    private static let monoFontFamilies: [FontFamily] = {
        let fm = NSFontManager.shared
        let monoKeywords = [
            "mono", "code", "nerd", "powerline", "hack", "consol",
            "fira", "jetbrains", "cascadia", "source code", "iosevka",
            "inconsolata", "terminus", "victor", "courier", " nf",
            "meslo", "droid sans m", "roboto mono", "ubuntu mono",
            "liberation mono", "dejavu sans mono", "fantasque",
            "anonymous", "bitstream vera sans mono", "pt mono",
            "sf mono", "monaco", "menlo", "andale mono",
        ]
        return fm.availableFontFamilies.compactMap { family in
            guard let members = fm.availableMembers(ofFontFamily: family) else { return nil }
            let familyLower = family.lowercased()
            guard let firstName = members.first?[0] as? String,
                  let font = NSFont(name: firstName, size: 12) else { return nil }
            let isMono = font.isFixedPitch
                || monoKeywords.contains(where: { familyLower.contains($0) })
            guard isMono else { return nil }
            let variants = members.compactMap { member -> FontVariant? in
                guard let name = member[0] as? String, let style = member[1] as? String else { return nil }
                return FontVariant(postScriptName: name, styleName: style)
            }
            guard !variants.isEmpty else { return nil }
            return FontFamily(name: family, variants: variants)
        }
    }()

    var body: some View {
        Form {
            Section(appState.localized("Theme")) {
                Picker(appState.localized("Terminal Theme"), selection: $appState.terminalThemeID) {
                    Text(appState.localized("System (auto)")).tag("system")
                    Divider()
                    ForEach(NamedTerminalTheme.builtIn) { theme in
                        Text(theme.displayName).tag(theme.id)
                    }
                }
            }
            Section(appState.localized("Font")) {
                Picker(appState.localized("Font"), selection: $appState.terminalFontName) {
                    ForEach(Self.monoFontFamilies) { family in
                        if family.variants.count == 1 {
                            Text(family.name).tag(family.variants[0].postScriptName)
                        } else {
                            Section(family.name) {
                                ForEach(family.variants) { variant in
                                    Text("\(family.name) \(variant.styleName)")
                                        .tag(variant.postScriptName)
                                }
                            }
                        }
                    }
                }
                HStack {
                    Text(appState.localized("Size"))
                    Slider(value: $appState.terminalFontSize, in: 9...24, step: 1)
                    Text("\(Int(appState.terminalFontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 40)
                }
                if TerminalFontRegistry.preferredNerdFontName == nil {
                    Text(appState.localized("No Nerd Font is installed. oh-my-zsh theme icons require a Nerd Font such as MesloLGS NF or JetBrainsMono Nerd Font."))
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    LabeledContent(appState.localized("Nerd Font")) {
                        Text(TerminalFontRegistry.preferredNerdFontName ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section(appState.localized("Window")) {
                HStack {
                    Text(appState.localized("Background Opacity"))
                    Slider(value: $appState.terminalOpacity, in: 0.3...1.0)
                    Text("\(Int(appState.terminalOpacity * 100))%")
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }
            Section(appState.localized("Preview")) {
                let resolved = NamedTerminalTheme.resolve(id: appState.terminalThemeID, colorScheme: colorScheme)
                ThemePreviewView(theme: resolved, fontName: appState.terminalFontName, fontSize: appState.terminalFontSize)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .formStyle(.grouped)
    }
}

private struct FontFamily: Identifiable {
    let name: String
    let variants: [FontVariant]
    var id: String { name }
}

private struct FontVariant: Identifiable {
    let postScriptName: String
    let styleName: String
    var id: String { postScriptName }
}

private struct ThemePreviewView: View {
    let theme: NamedTerminalTheme
    var fontName: String = "Menlo-Regular"
    var fontSize: Double = 13

    private var previewFont: Font {
        if let nsFont = NSFont(name: fontName, size: fontSize) {
            return Font(nsFont)
        }
        return .system(size: fontSize, design: .monospaced)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: theme.palette.background)
            VStack(alignment: .leading, spacing: 4) {
                Text("$ ls -la")
                    .foregroundColor(Color(nsColor: theme.palette.foreground))
                Text("drwxr-xr-x  12 user  staff  384 Jan  1 12:00 .")
                    .foregroundColor(Color(nsColor: theme.palette.foreground).opacity(0.7))
                Text("-rw-r--r--   1 user  staff  1024 Jan  1 12:00 README.md")
                    .foregroundColor(Color(nsColor: theme.palette.foreground).opacity(0.7))
                Text("$ echo \"Hello, World!\"")
                    .foregroundColor(Color(nsColor: theme.palette.foreground))
                Text("Hello, World!")
                    .foregroundColor(Color(nsColor: theme.palette.foreground).opacity(0.8))
            }
            .font(previewFont)
            .padding(10)
        }
    }
}

private struct NotificationSettingsTab: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("notificationMode") private var notificationMode = TaskNotificationMode.all.rawValue
    @AppStorage("notificationSoundEnabled") private var notificationSoundEnabled = true
    @AppStorage("notificationIncludesCommandText") private var notificationIncludesCommandText = false
    @State private var authorizationStatus = UNAuthorizationStatus.notDetermined

    var body: some View {
        Form {
            Section(appState.localized("Background Notifications")) {
                Picker(appState.localized("Notification Mode"), selection: $notificationMode) {
                    ForEach(TaskNotificationMode.allCases) { mode in
                        Text(appState.localized(mode.title)).tag(mode.rawValue)
                    }
                }
                Toggle(appState.localized("Notification Sound"), isOn: $notificationSoundEnabled)
                Toggle(appState.localized("Include command text in notifications"), isOn: $notificationIncludesCommandText)
                Text(appState.localized("Keep this off when commands may contain secrets. Spot Terminal never includes command output in notifications."))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Section(appState.localized("Permissions")) {
                PermissionStatusRow(
                    title: appState.localized("Notifications"),
                    isGranted: authorizationStatus == .authorized || authorizationStatus == .provisional,
                    grantedText: notificationStatusText,
                    missingText: notificationStatusText
                )
                Button(appState.localized("Refresh Status")) {
                    refreshNotificationStatus()
                }
            }
            Section(appState.localized("Test")) {
                Button(appState.localized("Send Test Notification")) {
                    appState.sendTestNotification()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            refreshNotificationStatus()
        }
    }

    private var notificationStatusText: String {
        switch authorizationStatus {
        case .notDetermined:
            return appState.localized("Not requested")
        case .denied:
            return appState.localized("Denied")
        case .authorized:
            return appState.localized("Allowed")
        case .provisional:
            return appState.localized("Allowed quietly")
        @unknown default:
            return appState.localized("Unknown")
        }
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                authorizationStatus = settings.authorizationStatus
            }
        }
    }
}

struct ArchiveBrowserTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchQuery = ""
    @State private var selectedArchiveID: UUID?

    private var archives: [ArchivedSessionSummary] {
        if searchQuery.isEmpty {
            return appState.archiveStore.recentSummaries(limit: 500)
        }
        return appState.archiveStore.searchSummaries(query: searchQuery, limit: 500)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(appState.localized("Search commands and output..."), text: $searchQuery)
                    .textFieldStyle(.plain)
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)

            Divider()

            if archives.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "archivebox")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text(searchQuery.isEmpty ? appState.localized("No archived sessions") : appState.localized("No matches found"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(archives, selection: $selectedArchiveID) { summary in
                    ArchiveRowView(summary: summary)
                        .tag(summary.id)
                }
                .listStyle(.inset)
            }
        }
    }
}

private struct ArchiveRowView: View {
    @EnvironmentObject private var appState: AppState
    let summary: ArchivedSessionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(summary.firstCommand)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .lineLimit(1)
            HStack(spacing: 8) {
                Text("\(summary.commandCount) \(summary.commandCount == 1 ? appState.localized("command") : appState.localized("commands"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(summary.archivedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
