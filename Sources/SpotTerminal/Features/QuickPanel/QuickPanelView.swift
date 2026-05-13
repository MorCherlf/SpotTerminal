// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

struct QuickPanelView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var inputFocused: Bool
    @State private var command = ""
    @State private var forceKillAvailable = false

    let onDismiss: () -> Void
    let onExpand: () -> Void

    private var theme: TerminalTheme {
        TerminalTheme.resolve(appState.terminalThemeKind, colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(spacing: 0) {
                inputRow
                if showsSuggestions {
                    suggestionsPanel
                } else {
                    Divider().opacity(appState.quickSession.entries.isEmpty ? 0 : 1)
                    outputView
                }
                statusRow
            }
            .padding(14)
        }
        .frame(width: 700, height: 420)
        .onAppear {
            appState.updateQuickSuggestions(query: command)
            refocusInput()
        }
        .onChange(of: command) { _, value in
            appState.updateQuickSuggestions(query: value)
            appState.suggestionEngine.normalize(currentCommand: value)
        }
        .onChange(of: appState.quickSession.isRunning) { _, isRunning in
            if !isRunning {
                refocusInput()
            }
        }
        .onExitCommand {
            onDismiss()
        }
    }

    private var inputRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)

            QuickCommandInputField(
                text: $command,
                isFocused: Binding(
                    get: { inputFocused },
                    set: { inputFocused = $0 }
                ),
                placeholder: "> _",
                onCommit: submit,
                onMoveSelection: moveSuggestionSelection,
                onConfirmSuggestion: confirmSuggestion
            )
            .frame(height: 24)

            if appState.quickSession.isRunning {
                ProgressView()
                    .scaleEffect(0.55)
            }
        }
        .padding(.horizontal, 4)
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private var outputView: some View {
        if appState.quickPanelShowsArchivedTranscript {
            CommandTranscriptView(session: appState.quickSession, theme: theme)
                .environment(\.terminalTheme, theme)
                .id(appState.quickSession.id)
                .frame(maxHeight: .infinity)
        } else if appState.quickSession.entries.isEmpty {
            Spacer(minLength: 0)
        } else {
            ReadOnlyCommandOutputTerminalView(
                session: appState.quickSession,
                themeKind: appState.terminalThemeKind,
                themeID: appState.terminalThemeID,
                colorScheme: colorScheme
            )
                .id(appState.quickSession.id)
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var suggestionsPanel: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(appState.suggestionEngine.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                        if appState.suggestionEngine.sectionHeaderVisibility(at: index) {
                            Text(suggestion.sectionTitle)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.top, index == 0 ? 0 : 4)
                                .padding(.horizontal, 2)
                        }
                        Button {
                            applySuggestion(at: index)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: suggestion.systemImage)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                                        .lineLimit(1)
                                    Text(suggestion.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .background(suggestionBackground(isSelected: index == appState.suggestionEngine.selectedIndex))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .id(index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .onChange(of: appState.suggestionEngine.selectedIndex) { _, index in
                guard let index else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }

    private var showsSuggestions: Bool {
        !appState.quickSession.isRunning
            && !appState.quickPanelShowsArchivedTranscript
            && appState.suggestionEngine.hasSuggestions
            && (appState.quickSession.entries.isEmpty || !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var statusRow: some View {
        HStack(spacing: 10) {
            if let last = appState.quickSession.entries.last {
                StatusLabel(entry: last, isRunning: appState.quickSession.isRunning)
            } else {
                Text(appState.localized("Double-tap Command or press Command-Shift-Space"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if appState.quickSession.isRunning {
                Button(forceKillAvailable ? appState.localized("Force Kill") : appState.localized("Interrupt")) {
                    if forceKillAvailable {
                        appState.quickSession.forceKill()
                    } else {
                        appState.quickSession.interrupt()
                        armForceKill()
                    }
                }
                .buttonStyle(.bordered)
            }

            Button(appState.localized("Expand")) {
                DispatchQueue.main.async {
                    appState.expandQuickSessionToTerminal()
                    onExpand()
                    onDismiss()
                }
            }
            .disabled(!appState.canExpandQuickSession)
        }
        .font(.callout)
        .padding(.top, 10)
    }

    private func submit() {
        appState.suggestionEngine.reset()
        if appState.quickSession.isRunning {
            appState.quickSession.sendInteractiveInput(command)
            DispatchQueue.main.async {
                command = ""
                refocusInput()
            }
            return
        }

        appState.prepareQuickSessionForNewCommand()
        appState.quickSession.submit(command)
        DispatchQueue.main.async {
            command = ""
            appState.updateQuickSuggestions(query: "")
            forceKillAvailable = false
            refocusInput()
        }
    }

    private func applySuggestion(at index: Int) {
        let action = appState.suggestionEngine.selectSuggestion(at: index)
        handleAction(action)
    }

    private func moveSuggestionSelection(delta: Int) -> Bool {
        guard showsSuggestions else { return false }
        return appState.suggestionEngine.moveSelection(delta: delta)
    }

    private func confirmSuggestion(acceptFirstWhenUnselected: Bool) -> Bool {
        guard showsSuggestions else { return false }

        if acceptFirstWhenUnselected {
            let action = appState.suggestionEngine.handleTab(currentCommand: command)
            if action != .none {
                handleAction(action)
                return true
            }
            return false
        }

        let action = appState.suggestionEngine.handleEnter(currentCommand: command)
        if action != .none {
            handleAction(action)
            return true
        }
        return false
    }

    private func handleAction(_ action: SuggestionAction) {
        DispatchQueue.main.async {
            switch action {
            case .replaceCommand(let value):
                command = value
            case .openArchive(let id):
                command = ""
                appState.openArchivedSession(id: id)
            case .none:
                break
            }
            refocusInput()
        }
    }

    private func suggestionBackground(isSelected: Bool) -> some ShapeStyle {
        isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.045)
    }

    private func armForceKill() {
        forceKillAvailable = false
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                if appState.quickSession.isRunning {
                    forceKillAvailable = true
                }
            }
        }
    }

    private func refocusInput() {
        inputFocused = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            inputFocused = true
        }
    }
}
