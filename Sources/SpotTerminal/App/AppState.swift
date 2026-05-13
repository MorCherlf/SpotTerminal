// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var quickSession = CommandSession(title: "Quick Command") {
        didSet { bindSessions() }
    }
    @Published var terminalSession = CommandSession(title: "Terminal") {
        didSet { bindSessions() }
    }
    let tabStore = TerminalTabStore()
    @Published private(set) var backgroundSessions: [CommandSession] = []
    @Published private(set) var activeBackgroundSessionID: UUID?
    @Published private(set) var expandedQuickSession: CommandSession?
    @Published private(set) var recentArchivedSessions: [ArchivedSessionSummary] = []
    @Published private(set) var quickPanelShowsArchivedTranscript = false
    let suggestionEngine = SuggestionEngine()
    @Published var terminalThemeKind: TerminalThemeKind = .system
    @Published var terminalThemeID: String = "system"
    @Published var terminalFontName: String = TerminalFontRegistry.resolvedInitialFontName(
        stored: UserDefaults.standard.string(forKey: "terminalFontName")
    ) {
        didSet { UserDefaults.standard.set(terminalFontName, forKey: "terminalFontName") }
    }
    @Published var terminalFontSize: Double = UserDefaults.standard.object(forKey: "terminalFontSize") as? Double ?? 13 {
        didSet { UserDefaults.standard.set(terminalFontSize, forKey: "terminalFontSize") }
    }
    @Published var terminalOpacity: Double = UserDefaults.standard.object(forKey: "terminalOpacity") as? Double ?? 1.0 {
        didSet { UserDefaults.standard.set(terminalOpacity, forKey: "terminalOpacity") }
    }
    @Published var quickPanelHotKeyID: String = UserDefaults.standard.string(forKey: "quickPanelHotKeyID") ?? QuickPanelHotKey.doubleLeftCommand.rawValue {
        didSet { UserDefaults.standard.set(quickPanelHotKeyID, forKey: "quickPanelHotKeyID") }
    }
    @Published var appLanguageID: String = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.system.rawValue {
        didSet {
            UserDefaults.standard.set(appLanguageID, forKey: "appLanguage")
            PrivacySafeLogger.shared.event("language_changed", metadata: ["language": appLanguageID])
        }
    }

    var taskNotifier: TaskNotifier?

    private var sessionCancellables: Set<AnyCancellable> = []
    private var notifiedBackgroundEntryIDs: Set<UUID> = []
    let archiveStore = SessionArchiveStore()
    private let localizer = AppLocalizer()

    var quickPanelHotKey: QuickPanelHotKey {
        QuickPanelHotKey.from(rawValue: quickPanelHotKeyID)
    }

    var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageID)
    }

    func localized(_ key: String) -> String {
        localizer.localized(key, language: appLanguage)
    }

    func increaseTerminalFontSize() {
        terminalFontSize = min(24, terminalFontSize + 1)
        PrivacySafeLogger.shared.event("terminal_font_size_changed", metadata: ["mode": "increase"])
    }

    func decreaseTerminalFontSize() {
        terminalFontSize = max(9, terminalFontSize - 1)
        PrivacySafeLogger.shared.event("terminal_font_size_changed", metadata: ["mode": "decrease"])
    }

    func resetTerminalFontSize() {
        terminalFontSize = 13
        PrivacySafeLogger.shared.event("terminal_font_size_changed", metadata: ["mode": "reset"])
    }

    init() {
        suggestionEngine.configure(archiveStore: archiveStore)
        suggestionEngine.onOpenArchive = { [weak self] id in
            self?.openArchivedSession(id: id)
        }
        reloadArchiveSummaries()
        updateQuickSuggestions(query: "")
        bindSessions()
    }

    var runningTaskCount: Int {
        ([quickSession, terminalSession] + backgroundSessions).filter(\.isRunning).count
    }

    var runningTaskTitles: [String] {
        ([quickSession, terminalSession] + backgroundSessions).compactMap { session in
            guard session.isRunning, let command = session.entries.last?.command else { return nil }
            return "\(session.title): \(command)"
        }
    }

    var runningBackgroundTaskCount: Int {
        backgroundSessions.filter(\.isRunning).count
    }

    var runningBackgroundTaskTitles: [String] {
        backgroundSessions.compactMap { session in
            guard session.isRunning, let command = session.entries.last?.command else { return nil }
            return "\(session.title): \(command)"
        }
    }

    var backgroundTaskSnapshots: [BackgroundTaskSnapshot] {
        backgroundSessions.compactMap { session in
            guard let entry = session.entries.last else { return nil }
            return BackgroundTaskSnapshot(
                id: session.id,
                title: session.title,
                command: entry.command,
                isRunning: session.isRunning,
                state: entry.state,
                duration: entry.duration
            )
        }
    }

    var completedBackgroundTaskCount: Int {
        backgroundSessions.filter { !$0.isRunning }.count
    }

    var canExpandQuickSession: Bool {
        !quickPanelShowsArchivedTranscript && !quickSession.entries.isEmpty
    }

    func expandQuickSessionToTerminal() {
        PrivacySafeLogger.shared.event("quick_session_expanded")
        tabStore.createTabForExpandedSession(quickSession)
        quickSession = CommandSession(title: "Quick Command")
        bindSessions()
    }

    func clearExpandedQuickSession() {
        expandedQuickSession = nil
        bindSessions()
    }

    func closeQuickPanelSession() {
        if quickPanelShowsArchivedTranscript {
            quickPanelShowsArchivedTranscript = false
            activeBackgroundSessionID = nil
            quickSession = CommandSession(title: "Quick Command")
            updateQuickSuggestions(query: "")
            bindSessions()
            return
        }

        guard !quickSession.entries.isEmpty else {
            activeBackgroundSessionID = nil
            return
        }

        if let activeBackgroundSessionID {
            if !quickSession.isRunning {
                archiveSession(quickSession)
                backgroundSessions.removeAll { $0.id == activeBackgroundSessionID }
                quickSession = CommandSession(title: "Quick Command")
            }
            self.activeBackgroundSessionID = nil
            bindSessions()
            return
        }

        if quickSession.isRunning {
            prepareBackgroundSession(quickSession)
            backgroundSessions.append(quickSession)
        } else {
            archiveSession(quickSession)
        }
        quickSession = CommandSession(title: "Quick Command")
        bindSessions()
    }

    func startFreshQuickSessionIfNeeded() {
        guard activeBackgroundSessionID == nil, !quickSession.entries.isEmpty else { return }
        quickPanelShowsArchivedTranscript = false
        quickSession = CommandSession(title: "Quick Command")
    }

    func showBackgroundSession(id: UUID) {
        guard let session = backgroundSessions.first(where: { $0.id == id }) else { return }
        activeBackgroundSessionID = id
        quickPanelShowsArchivedTranscript = false
        quickSession = session
    }

    func prepareQuickSessionForNewCommand() {
        quickPanelShowsArchivedTranscript = false
        activeBackgroundSessionID = nil
        quickSession = CommandSession(title: "Quick Command")
        bindSessions()
    }

    func updateQuickSuggestions(query: String) {
        suggestionEngine.updateSuggestions(query: query, workingDirectory: quickSession.currentDirectory)
    }

    func openArchivedSession(id: UUID) {
        guard let record = archiveStore.record(id: id) else { return }
        let session = CommandSession(title: record.title, startShell: false)
        session.append(entries: record.entries.map(CommandEntry.init(archivedEntry:)))
        quickPanelShowsArchivedTranscript = true
        activeBackgroundSessionID = nil
        quickSession = session
        bindSessions()
    }

    func clearCompletedBackgroundSessions() {
        PrivacySafeLogger.shared.event("background_sessions_clear_completed", metadata: ["count": "\(completedBackgroundTaskCount)"])
        backgroundSessions
            .filter { !$0.isRunning }
            .forEach(archiveSession)
        backgroundSessions.removeAll { !$0.isRunning }
        if let activeBackgroundSessionID,
           !backgroundSessions.contains(where: { $0.id == activeBackgroundSessionID }) {
            self.activeBackgroundSessionID = nil
        }
        bindSessions()
    }

    func interruptActiveCommand() {
        PrivacySafeLogger.shared.event("command_interrupt_requested")
        if quickSession.isRunning {
            quickSession.interrupt()
        } else if terminalSession.isRunning {
            terminalSession.interrupt()
        } else if let session = backgroundSessions.first(where: \.isRunning) {
            session.interrupt()
        }
    }

    func sendTestNotification() {
        PrivacySafeLogger.shared.event("test_notification_requested")
        taskNotifier?.requestAuthorizationIfNeeded()
        taskNotifier?.notifyTest()
    }

    private func bindSessions() {
        sessionCancellables.removeAll()

        tabStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &sessionCancellables)

        quickSession.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &sessionCancellables)

        terminalSession.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &sessionCancellables)

        for session in backgroundSessions {
            prepareBackgroundSession(session)
            session.objectWillChange
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &sessionCancellables)
        }

        expandedQuickSession?.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &sessionCancellables)
    }

    private func prepareBackgroundSession(_ session: CommandSession) {
        session.onFinish = { [weak self, weak session] entry in
            guard let self, let session else { return }
            PrivacySafeLogger.shared.event(
                "background_session_finished",
                metadata: [
                    "exit_code": "\(entry.exitCodeForLog)",
                    "duration_ms": "\(Int(entry.duration * 1000))"
                ]
            )
            guard self.activeBackgroundSessionID != session.id else { return }
            guard self.notifiedBackgroundEntryIDs.insert(entry.id).inserted else { return }
            self.taskNotifier?.notifyTaskFinished(sessionID: session.id, entry: entry)
        }
    }

    private func archiveSession(_ session: CommandSession) {
        archiveStore.archive(session)
        reloadArchiveSummaries()
    }

    private func reloadArchiveSummaries() {
        recentArchivedSessions = archiveStore.recentSummaries()
        updateQuickSuggestions(query: "")
    }
}

struct BackgroundTaskSnapshot: Identifiable, Equatable {
    var id: UUID
    var title: String
    var command: String
    var isRunning: Bool
    var state: CommandRunState
    var duration: TimeInterval
}

private extension CommandEntry {
    init(archivedEntry: ArchivedCommandEntry) {
        self.init(
            command: archivedEntry.command,
            startedAt: archivedEntry.startedAt,
            finishedAt: archivedEntry.finishedAt,
            output: archivedEntry.output,
            state: CommandRunState(archivedState: archivedEntry.state)
        )
    }
}

private extension CommandRunState {
    init(archivedState: ArchivedCommandState) {
        switch archivedState {
        case .running:
            self = .running
        case .finished(let exitCode):
            self = .finished(exitCode: exitCode)
        case .interrupted:
            self = .interrupted
        }
    }
}
