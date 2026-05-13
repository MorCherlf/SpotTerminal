// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

struct CommandTranscriptView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var session: CommandSession
    var theme: TerminalTheme

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if session.entries.isEmpty {
                        emptyState
                    } else {
                        ForEach(session.entries) { entry in
                            CommandEntryView(entry: entry)
                                .id(entry.id)
                        }
                    }
                }
                .padding(16)
            }
            .onChange(of: session.entries) { _, entries in
                guard let last = entries.last else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.localized("No commands yet"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.text)
            Text(appState.localized("Run a command here, or double-tap Command for the floating panel."))
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 28)
    }
}

private struct CommandEntryView: View {
    let entry: CommandEntry
    @Environment(\.terminalTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("$ \(entry.command)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.prompt)
                    .textSelection(.enabled)
                Spacer()
                StatusLabel(entry: entry, isRunning: entry.state == .running)
            }

            Text(entry.displayOutput)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(theme.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(theme.background.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }
}

private extension CommandEntry {
    var displayOutput: String {
        let stripped = entryOutputWithoutANSIEscapes
        return stripped.isEmpty ? " " : stripped
    }

    var entryOutputWithoutANSIEscapes: String {
        output.replacingOccurrences(
            of: "\u{001B}\\[[0-?]*[ -/]*[@-~]",
            with: "",
            options: .regularExpression
        )
    }
}

private struct TerminalThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = TerminalTheme.light
}

extension EnvironmentValues {
    var terminalTheme: TerminalTheme {
        get { self[TerminalThemeEnvironmentKey.self] }
        set { self[TerminalThemeEnvironmentKey.self] = newValue }
    }
}

struct StatusLabel: View {
    @EnvironmentObject private var appState: AppState
    let entry: CommandEntry
    let isRunning: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Label(labelText, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(color)
                .labelStyle(.titleAndIcon)
        }
    }

    private var labelText: String {
        switch entry.state {
        case .running:
            return format(entry.duration)
        case .finished(let code):
            return code == 0 ? "\(appState.localized("Done")) \(format(entry.duration))" : "\(appState.localized("Exit")) \(code) \(format(entry.duration))"
        case .interrupted:
            return "\(appState.localized("Interrupted")) \(format(entry.duration))"
        }
    }

    private var symbol: String {
        switch entry.state {
        case .running:
            return "timer"
        case .finished(let code):
            return code == 0 ? "checkmark.circle.fill" : "xmark.circle.fill"
        case .interrupted:
            return "stop.circle.fill"
        }
    }

    private var color: Color {
        switch entry.state {
        case .running:
            return .secondary
        case .finished(let code):
            return code == 0 ? .green : .red
        case .interrupted:
            return .orange
        }
    }

    private func format(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration))
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
    }
}
