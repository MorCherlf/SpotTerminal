// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import AppKit
import CoreText
import SwiftTerm
import SwiftUI

// MARK: - Font with fallback cascade for special characters

func makeTerminalFont(name: String, size: Double) -> NSFont {
    let effectiveName = TerminalFontRegistry.renderableFontName(for: name)
    let cacheKey = "\(effectiveName)-\(size)"
    if let cached = TerminalFontRegistry.fontCache[cacheKey] {
        return cached
    }
    guard let baseFont = NSFont(name: effectiveName, size: size) else {
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
    let cascadeDescriptors = TerminalFontRegistry.cascadeFontNames.compactMap { fallback -> NSFontDescriptor? in
        NSFont(name: fallback, size: size)?.fontDescriptor
    }
    guard !cascadeDescriptors.isEmpty else {
        TerminalFontRegistry.fontCache[cacheKey] = baseFont
        return baseFont
    }
    let descriptor = baseFont.fontDescriptor.addingAttributes([
        NSFontDescriptor.AttributeName(rawValue: kCTFontCascadeListAttribute as String): cascadeDescriptors,
    ])
    let font = NSFont(descriptor: descriptor, size: size) ?? baseFont
    TerminalFontRegistry.fontCache[cacheKey] = font
    return font
}

enum TerminalFontRegistry {
    static var fontCache: [String: NSFont] = [:]

    static let preferredDefaultFontName: String = {
        registerBundledFonts()
        return preferredFullNerdFontName ?? preferredNerdFontName ?? "Menlo-Regular"
    }()

    static let preferredFullNerdFontName: String? = {
        registerBundledFonts()
        let preferredNames = [
            "JetBrainsMonoNFM-Regular",
            "JetBrainsMono Nerd Font Mono",
            "JetBrainsMonoNerdFontMono-Regular",
            "JetBrainsMonoNerdFont-Regular",
            "JetBrainsMono Nerd Font Mono Regular",
            "MesloLGS NF Regular",
            "MesloLGS-NF-Regular",
            "HackNerdFont-Regular",
            "Hack Nerd Font Mono Regular",
            "FiraCodeNerdFont-Regular",
            "FiraCode Nerd Font Mono Regular",
            "CaskaydiaCoveNerdFont-Regular",
        ]
        if let name = preferredNames.first(where: fontNameSupportsTerminalSymbols) {
            return name
        }
        return installedFontNames.first { name in
            let lower = name.lowercased()
            return fontNameSupportsTerminalSymbols(name)
                && (lower.contains("nerdfont") || lower.contains("nerd font") || lower.contains(" nf"))
                && !lower.contains("symbols")
        }
    }()

    static let preferredNerdFontName: String? = {
        registerBundledFonts()
        let preferredNames = [
            preferredFullNerdFontName,
            "JetBrainsMonoNFM-Regular",
            "JetBrainsMono Nerd Font Mono",
            "MesloLGS NF Regular",
            "MesloLGS-NF-Regular",
            "JetBrainsMonoNerdFont-Regular",
            "JetBrainsMono Nerd Font Mono Regular",
            "HackNerdFont-Regular",
            "Hack Nerd Font Mono Regular",
            "FiraCodeNerdFont-Regular",
            "FiraCode Nerd Font Mono Regular",
            "CaskaydiaCoveNerdFont-Regular",
            "SymbolsNFM",
            "SymbolsNerdFontMono-Regular",
            "Symbols Nerd Font Mono",
        ].compactMap { $0 }
        if let name = preferredNames.first(where: { NSFont(name: $0, size: 13) != nil }) {
            return name
        }
        return installedFontNames.first { name in
            let lower = name.lowercased()
            return lower.contains("nerdfont") || lower.contains("nerd font") || lower.contains(" nf")
        }
    }()

    static let cascadeFontNames: [String] = {
        registerBundledFonts()
        let preferred = [
            preferredFullNerdFontName,
            preferredNerdFontName,
            "JetBrainsMonoNFM-Regular",
            "JetBrainsMonoNFM-Bold",
            "JetBrainsMono Nerd Font Mono",
            "SymbolsNerdFontMono-Regular",
            "SymbolsNFM",
            "Symbols Nerd Font Mono", "Symbols Nerd Font",
            "MesloLGS NF", "MesloLGS Nerd Font Mono",
            "JetBrainsMono Nerd Font Mono", "JetBrainsMono Nerd Font",
            "Hack Nerd Font Mono", "Hack Nerd Font",
            "FiraCode Nerd Font Mono", "FiraCode Nerd Font",
            "CaskaydiaCove Nerd Font Mono", "CaskaydiaCove Nerd Font",
            "SauceCodePro Nerd Font Mono", "SauceCodePro Nerd Font",
            "PowerlineSymbols", "Apple Symbols", "Menlo",
        ].compactMap { $0 }
        return Array(NSOrderedSet(array: preferred + installedNerdFontNames).compactMap { $0 as? String })
    }()

    static func registerBundledFonts() {
        guard !didRegisterBundledFonts else { return }
        didRegisterBundledFonts = true
        for resource in bundledFontResources {
            guard let url = bundledFontURL(for: resource) else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func resolvedInitialFontName(stored: String?) -> String {
        guard let stored, !stored.isEmpty else {
            return preferredDefaultFontName
        }
        return renderableFontName(for: stored)
    }

    static func renderableFontName(for requestedName: String) -> String {
        registerBundledFonts()
        if fontNameSupportsTerminalSymbols(requestedName) {
            return requestedName
        }
        return preferredDefaultFontName
    }

    static func fontNameSupportsTerminalSymbols(_ name: String) -> Bool {
        guard let font = NSFont(name: name, size: 13) else { return false }
        return fontSupportsTerminalSymbols(font)
    }

    static func fontSupportsTerminalSymbols(_ font: NSFont) -> Bool {
        var characters = requiredTerminalSymbols
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        let mapped = CTFontGetGlyphsForCharacters(font as CTFont, &characters, &glyphs, characters.count)
        return mapped && glyphs.allSatisfy { $0 != 0 }
    }

    private static let installedNerdFontNames: [String] = installedFontNames.filter { name in
        let lower = name.lowercased()
        return lower.contains("nerdfont")
            || lower.contains("nerd font")
            || lower.contains("symbols nerd")
            || lower.contains("powerline")
    }

    private static let installedFontNames: [String] = {
        registerBundledFonts()
        return NSFontManager.shared.availableFontFamilies.flatMap { family in
            let members = NSFontManager.shared.availableMembers(ofFontFamily: family)?.compactMap { $0[0] as? String } ?? []
            return [family] + members
        }
    }()

    private static let bundledFontResources = [
        "JetBrainsMonoNerdFontMono-Regular",
        "JetBrainsMonoNerdFontMono-Bold",
        "SymbolsNerdFontMono-Regular",
    ]

    private static let requiredTerminalSymbols: [UniChar] = [
        0xE0B0, // Powerline separator used by agnoster-style prompts.
        0xE0A0, // Powerline branch glyph used by many oh-my-zsh themes.
    ]

    private static func bundledFontURL(for resource: String) -> URL? {
        let fileName = "\(resource).ttf"
        let mainBundleCandidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent(fileName),
            Bundle.main.resourceURL?.appendingPathComponent("Fonts/\(fileName)"),
            Bundle.main.resourceURL?.appendingPathComponent("SpotTerminal_SpotTerminal.bundle/\(fileName)"),
        ]
        if let url = mainBundleCandidates.compactMap({ $0 }).first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return url
        }

        guard Bundle.main.bundleURL.pathExtension != "app" else { return nil }
        return Bundle.module.url(forResource: resource, withExtension: "ttf", subdirectory: "Fonts")
            ?? Bundle.module.url(forResource: resource, withExtension: "ttf")
    }

    private static var didRegisterBundledFonts = false
}

// MARK: - Tab Container (keeps terminal views alive across tab switches)

struct TerminalTabContainerView: NSViewRepresentable {
    var activeTabID: UUID
    var tabs: [TerminalTab]
    var activePaneID: UUID?
    var themeID: String
    var colorScheme: ColorScheme
    var fontName: String
    var fontSize: Double
    var backgroundOpacity: Double
    var onPaneTitleChanged: ((UUID, UUID, String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        container.autoresizingMask = [.width, .height]
        context.coordinator.container = container
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        let coordinator = context.coordinator

        let shellPaneIDs = Set(tabs.flatMap { tab in
            tab.expandedSession == nil ? tab.panes.map(\.id) : []
        })
        for id in Array(coordinator.terminals.keys) where !shellPaneIDs.contains(id) {
            coordinator.terminals[id]?.removeFromSuperview()
            coordinator.terminals.removeValue(forKey: id)
            coordinator.delegates.removeValue(forKey: id)
        }

        let activeTab = tabs.first { $0.id == activeTabID }
        let activeIsShellTab = activeTab?.expandedSession == nil

        for (_, terminal) in coordinator.terminals {
            terminal.isHidden = true
        }

        guard activeIsShellTab else { return }
        guard let activeTab, !activeTab.panes.isEmpty else { return }

        for (index, pane) in activeTab.panes.enumerated() {
            let terminal = terminalView(
                for: pane,
                tabID: activeTab.id,
                container: container,
                coordinator: coordinator
            )
            terminal.isHidden = false
            terminal.frame = frame(
                forPaneAt: index,
                paneCount: activeTab.panes.count,
                bounds: container.bounds,
                axis: activeTab.splitAxis
            )
            applyTheme(to: terminal)
        }

        if let activePaneID, let terminal = coordinator.terminals[activePaneID] {
            DispatchQueue.main.async {
                terminal.window?.makeFirstResponder(terminal)
            }
        }
    }

    private func terminalView(
        for pane: TerminalPane,
        tabID: UUID,
        container: NSView,
        coordinator: Coordinator
    ) -> SecureLocalProcessTerminalView {
        if let terminal = coordinator.terminals[pane.id] {
            return terminal
        }

        let delegate = ShellTerminalDelegate()
        let callback = onPaneTitleChanged
        let paneID = pane.id
        delegate.onTitleChanged = { title in
            callback?(tabID, paneID, title)
        }
        let terminal = SecureLocalProcessTerminalView(frame: container.bounds)
        terminal.processDelegate = delegate
        delegate.attach(terminal)
        terminal.autoresizingMask = []
        terminal.metalBufferingMode = .perFrameAggregated
        try? terminal.setUseMetal(false)
        applyTheme(to: terminal)

        container.addSubview(terminal)
        coordinator.terminals[paneID] = terminal
        coordinator.delegates[paneID] = delegate
        DispatchQueue.main.async {
            guard coordinator.terminals[paneID] === terminal else { return }
            let shell = Self.defaultShell()
            let execName = "-" + NSString(string: shell).lastPathComponent
            terminal.startProcess(
                executable: shell,
                execName: execName,
                currentDirectory: FileManager.default.homeDirectoryForCurrentUser.path
            )
        }
        return terminal
    }

    private func frame(
        forPaneAt index: Int,
        paneCount: Int,
        bounds: CGRect,
        axis: TerminalSplitAxis
    ) -> CGRect {
        guard paneCount > 1 else { return bounds }
        let divider: CGFloat = 1
        let totalDivider = CGFloat(paneCount - 1) * divider
        switch axis {
        case .vertical:
            let width = (bounds.width - totalDivider) / CGFloat(paneCount)
            let x = bounds.minX + CGFloat(index) * (width + divider)
            return CGRect(x: x, y: bounds.minY, width: width, height: bounds.height).integral
        case .horizontal:
            let height = (bounds.height - totalDivider) / CGFloat(paneCount)
            let y = bounds.maxY - CGFloat(index + 1) * height - CGFloat(index) * divider
            return CGRect(x: bounds.minX, y: y, width: bounds.width, height: height).integral
        }
    }

    private func applyTheme(to terminal: LocalProcessTerminalView) {
        let named = NamedTerminalTheme.resolve(id: themeID, colorScheme: colorScheme)
        let palette = named.palette
        let bg = backgroundOpacity < 1.0
            ? palette.background.withAlphaComponent(backgroundOpacity)
            : palette.background
        terminal.nativeForegroundColor = palette.foreground
        terminal.nativeBackgroundColor = bg
        terminal.selectedTextBackgroundColor = palette.selection
        terminal.caretColor = palette.cursor
        terminal.layer?.backgroundColor = bg.cgColor
        terminal.getTerminal().setCursorStyle(.steadyBlock)
        if palette.ansi.count == 16 {
            terminal.installColors(palette.ansi)
        }
        terminal.font = makeTerminalFont(name: fontName, size: fontSize)
        terminal.needsDisplay = true
    }

    static func defaultShell() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"], isSupportedShell(shell) {
            return shell
        }
        let bufferSize = sysconf(_SC_GETPW_R_SIZE_MAX)
        guard bufferSize > 0 else { return "/bin/zsh" }
        let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        var pwd = passwd()
        var result: UnsafeMutablePointer<passwd>?
        guard getpwuid_r(getuid(), &pwd, buffer, bufferSize, &result) == 0, let result else {
            return "/bin/zsh"
        }
        let shell = String(cString: result.pointee.pw_shell)
        return isSupportedShell(shell) ? shell : "/bin/zsh"
    }

    static func isSupportedShell(_ shell: String) -> Bool {
        guard shell.hasPrefix("/"),
              FileManager.default.isExecutableFile(atPath: shell) else {
            return false
        }
        let name = URL(fileURLWithPath: shell).lastPathComponent
        return name == "zsh" || name == "bash"
    }

    final class Coordinator {
        var terminals: [UUID: SecureLocalProcessTerminalView] = [:]
        var delegates: [UUID: ShellTerminalDelegate] = [:]
        weak var container: NSView?
    }
}

private extension String {
    var sanitizedTerminalTitle: String {
        String(
            unicodeScalars
                .filter { scalar in
                    scalar.value >= 0x20 && scalar.value != 0x7F
                }
                .prefix(80)
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class ShellTerminalDelegate: NSObject, LocalProcessTerminalViewDelegate {
    private weak var terminal: LocalProcessTerminalView?
    var onTitleChanged: ((String) -> Void)?

    func attach(_ terminal: LocalProcessTerminalView) {
        self.terminal = terminal
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        let sanitized = title.sanitizedTerminalTitle
        guard !sanitized.isEmpty else { return }
        onTitleChanged?(sanitized)
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        guard let terminal = source as? LocalProcessTerminalView else { return }
        let code = exitCode.map(String.init) ?? "unknown"
        terminal.feed(text: "\r\n[process exited: \(code)]\r\n")
    }
}

final class SecureLocalProcessTerminalView: LocalProcessTerminalView {
    private var secureTerminalDelegate: SecureLocalProcessTerminalDelegate?

    override init(frame: CGRect) {
        super.init(frame: frame)
        installSecureDelegate()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installSecureDelegate()
    }

    private func installSecureDelegate() {
        let delegate = SecureLocalProcessTerminalDelegate(owner: self)
        secureTerminalDelegate = delegate
        terminalDelegate = delegate
    }
}

final class SecureLocalProcessTerminalDelegate: NSObject, TerminalViewDelegate {
    private weak var owner: LocalProcessTerminalView?

    init(owner: LocalProcessTerminalView) {
        self.owner = owner
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        owner?.sizeChanged(source: source, newCols: newCols, newRows: newRows)
    }

    func setTerminalTitle(source: TerminalView, title: String) {
        owner?.setTerminalTitle(source: source, title: title.sanitizedTerminalTitle)
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        owner?.hostCurrentDirectoryUpdate(source: source, directory: directory)
    }

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        owner?.send(source: source, data: data)
    }

    func scrolled(source: TerminalView, position: Double) {
        owner?.scrolled(source: source, position: position)
    }

    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        guard let url = URL(string: link),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            PrivacySafeLogger.shared.event("terminal_link_blocked")
            return
        }
        NSWorkspace.shared.open(url)
    }

    func bell(source: TerminalView) {
        NSSound.beep()
    }

    func clipboardCopy(source: TerminalView, content: Data) {
        PrivacySafeLogger.shared.event("terminal_osc52_clipboard_blocked")
    }

    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}

    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
        owner?.rangeChanged(source: source, startY: startY, endY: endY)
    }
}

// MARK: - Standalone terminal view (kept for non-tab contexts)

struct SwiftTermTerminalView: NSViewRepresentable {
    var themeKind: TerminalThemeKind
    var themeID: String
    var colorScheme: ColorScheme
    var fontName: String = "Menlo-Regular"
    var fontSize: Double = 13
    var backgroundOpacity: Double = 1.0

    func makeCoordinator() -> ShellTerminalDelegate {
        ShellTerminalDelegate()
    }

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = SecureLocalProcessTerminalView(frame: .zero)
        terminal.processDelegate = context.coordinator
        context.coordinator.attach(terminal)
        terminal.autoresizingMask = [.width, .height]
        terminal.metalBufferingMode = .perFrameAggregated
        try? terminal.setUseMetal(false)
        applyTheme(to: terminal)

        let shell = TerminalTabContainerView.defaultShell()
        let execName = "-" + NSString(string: shell).lastPathComponent
        terminal.startProcess(
            executable: shell,
            execName: execName,
            currentDirectory: FileManager.default.homeDirectoryForCurrentUser.path
        )

        DispatchQueue.main.async {
            terminal.window?.makeFirstResponder(terminal)
        }
        return terminal
    }

    func updateNSView(_ terminal: LocalProcessTerminalView, context: Context) {
        applyTheme(to: terminal)
    }

    private func applyTheme(to terminal: LocalProcessTerminalView) {
        let named = NamedTerminalTheme.resolve(id: themeID, colorScheme: colorScheme)
        let palette = named.palette
        let bg = backgroundOpacity < 1.0
            ? palette.background.withAlphaComponent(backgroundOpacity)
            : palette.background
        terminal.nativeForegroundColor = palette.foreground
        terminal.nativeBackgroundColor = bg
        terminal.selectedTextBackgroundColor = palette.selection
        terminal.caretColor = palette.cursor
        terminal.layer?.backgroundColor = bg.cgColor
        terminal.getTerminal().setCursorStyle(.steadyBlock)
        if palette.ansi.count == 16 {
            terminal.installColors(palette.ansi)
        }
        terminal.font = makeTerminalFont(name: fontName, size: fontSize)
        terminal.needsDisplay = true
    }
}

// MARK: - Attached Shell Terminal View

struct AttachedShellTerminalView: NSViewRepresentable {
    @ObservedObject var session: CommandSession
    var themeKind: TerminalThemeKind
    var themeID: String
    var colorScheme: ColorScheme
    var backgroundOpacity: Double = 1.0

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session, isRunning: session.isRunning)
    }

    func makeNSView(context: Context) -> TerminalView {
        let terminal = TerminalView(frame: .zero)
        terminal.terminalDelegate = context.coordinator
        context.coordinator.attach(terminal)
        terminal.autoresizingMask = [.width, .height]
        terminal.metalBufferingMode = .perFrameAggregated
        try? terminal.setUseMetal(false)
        applyTheme(to: terminal)
        context.coordinator.configure(isRunning: session.isRunning)

        focus(terminal)
        return terminal
    }

    func updateNSView(_ terminal: TerminalView, context: Context) {
        applyTheme(to: terminal)
        context.coordinator.configure(isRunning: session.isRunning)
        focus(terminal)
    }

    static func dismantleNSView(_ terminal: TerminalView, coordinator: Coordinator) {
        coordinator.detach()
    }

    private func applyTheme(to terminal: TerminalView) {
        let named = NamedTerminalTheme.resolve(id: themeID, colorScheme: colorScheme)
        let palette = named.palette
        let bg = backgroundOpacity < 1.0
            ? palette.background.withAlphaComponent(backgroundOpacity)
            : palette.background
        terminal.nativeForegroundColor = palette.foreground
        terminal.nativeBackgroundColor = bg
        terminal.selectedTextBackgroundColor = palette.selection
        terminal.caretColor = palette.cursor
        terminal.layer?.backgroundColor = bg.cgColor
        terminal.getTerminal().setCursorStyle(.steadyBlock)
        if palette.ansi.count == 16 {
            terminal.installColors(palette.ansi)
        }
        terminal.needsDisplay = true
    }

    private func focus(_ terminal: TerminalView) {
        DispatchQueue.main.async {
            terminal.window?.makeFirstResponder(terminal)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            terminal.window?.makeFirstResponder(terminal)
        }
    }

    final class Coordinator: NSObject, TerminalViewDelegate {
        private let session: CommandSession
        weak var terminal: TerminalView?
        private var terminalConsumerID: UUID?
        private var renderedConsumerID: UUID?
        private var mode: Mode = .detached

        init(session: CommandSession, isRunning: Bool) {
            self.session = session
        }

        func attach(_ terminal: TerminalView) {
            self.terminal = terminal
        }

        func detach() {
            if let terminalConsumerID {
                session.shellSession.removeTerminalConsumer(id: terminalConsumerID)
            }
            if let renderedConsumerID {
                session.shellSession.removeRenderedOutputConsumer(id: renderedConsumerID)
            }
            terminalConsumerID = nil
            renderedConsumerID = nil
            mode = .detached
        }

        func configure(isRunning: Bool) {
            if isRunning {
                attachRenderedOutputIfNeeded()
            } else {
                attachInteractiveTerminalIfNeeded()
            }
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            session.shellSession.resize(cols: newCols, rows: newRows)
        }

        func setTerminalTitle(source: TerminalView, title: String) {}

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            session.shellSession.send(data: data)
        }

        func scrolled(source: TerminalView, position: Double) {}

        func clipboardCopy(source: TerminalView, content: Data) {
            PrivacySafeLogger.shared.event("terminal_osc52_clipboard_blocked")
        }

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

        private func attachRenderedOutputIfNeeded() {
            guard mode != .renderedOutput else { return }
            detach()
            mode = .renderedOutput
            terminal?.feed(text: "[attached to running quick command; showing live output]\r\n")
            renderedConsumerID = session.shellSession.addRenderedOutputConsumer { [weak self] text in
                DispatchQueue.main.async {
                    self?.terminal?.feed(text: text)
                }
            }
        }

        private func attachInteractiveTerminalIfNeeded() {
            guard mode != .interactiveTerminal else { return }
            detach()
            mode = .interactiveTerminal
            session.shellSession.prepareForTerminalAttachment { [weak self] in
                guard let self else { return }
                let consumerID = self.session.shellSession.addTerminalConsumer { [weak self] bytes in
                    DispatchQueue.main.async {
                        self?.terminal?.feed(byteArray: bytes)
                    }
                }
                DispatchQueue.main.async {
                    guard self.mode == .interactiveTerminal else {
                        self.session.shellSession.removeTerminalConsumer(id: consumerID)
                        return
                    }
                    self.terminalConsumerID = consumerID
                    self.session.shellSession.showInteractivePrompt()
                }
            }
        }

        private enum Mode {
            case detached
            case renderedOutput
            case interactiveTerminal
        }
    }
}

// MARK: - Read-Only Command Output Terminal View

struct ReadOnlyCommandOutputTerminalView: NSViewRepresentable {
    @ObservedObject var session: CommandSession
    var themeKind: TerminalThemeKind
    var themeID: String
    var colorScheme: ColorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeNSView(context: Context) -> TerminalView {
        let terminal = TerminalView(frame: .zero)
        terminal.terminalDelegate = context.coordinator
        context.coordinator.attach(terminal)
        terminal.autoresizingMask = [.width, .height]
        terminal.metalBufferingMode = .perFrameAggregated
        terminal.caretViewTracksFocus = false
        try? terminal.setUseMetal(false)
        applyTheme(to: terminal)

        let history = session.shellSession.renderedOutputSnapshot()
        if history.isEmpty {
            terminal.feed(text: "\r\n")
        } else {
            terminal.feed(text: history)
        }

        context.coordinator.consumerID = session.shellSession.addRenderedOutputConsumer { [weak terminal] text in
            DispatchQueue.main.async {
                terminal?.feed(text: text)
            }
        }

        return terminal
    }

    func updateNSView(_ terminal: TerminalView, context: Context) {
        applyTheme(to: terminal)
    }

    static func dismantleNSView(_ terminal: TerminalView, coordinator: Coordinator) {
        coordinator.detach()
    }

    private func applyTheme(to terminal: TerminalView) {
        let named = NamedTerminalTheme.resolve(id: themeID, colorScheme: colorScheme)
        let palette = named.palette
        terminal.nativeForegroundColor = palette.foreground
        terminal.nativeBackgroundColor = palette.background
        terminal.selectedTextBackgroundColor = palette.selection
        terminal.caretColor = .clear
        terminal.layer?.backgroundColor = palette.background.cgColor
        terminal.getTerminal().setCursorStyle(.steadyBlock)
        if palette.ansi.count == 16 {
            terminal.installColors(palette.ansi)
        }
        terminal.needsDisplay = true
    }

    final class Coordinator: NSObject, TerminalViewDelegate {
        private let session: CommandSession
        weak var terminal: TerminalView?
        var consumerID: UUID?

        init(session: CommandSession) {
            self.session = session
        }

        func attach(_ terminal: TerminalView) {
            self.terminal = terminal
        }

        func detach() {
            if let consumerID {
                session.shellSession.removeRenderedOutputConsumer(id: consumerID)
            }
            consumerID = nil
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            session.shellSession.resize(cols: newCols, rows: newRows)
        }

        func setTerminalTitle(source: TerminalView, title: String) {}

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func send(source: TerminalView, data: ArraySlice<UInt8>) {}

        func scrolled(source: TerminalView, position: Double) {}

        func clipboardCopy(source: TerminalView, content: Data) {
            PrivacySafeLogger.shared.event("terminal_osc52_clipboard_blocked")
        }

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}
