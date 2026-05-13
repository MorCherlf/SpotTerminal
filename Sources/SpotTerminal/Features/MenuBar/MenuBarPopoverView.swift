// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import SwiftUI

struct MenuBarPopoverView: View {
    @EnvironmentObject private var appState: AppState

    let onShowQuickPanel: () -> Void
    let onOpenSettings: () -> Void
    let onOpenTask: (UUID) -> Void
    let onInterrupt: () -> Void
    let onClearCompleted: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 300, height: 340)
        .background(LiquidGlassBackgroundView())
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Spot Terminal")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)

            Spacer()

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(appState.localized("Settings"))

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
    }

    @ViewBuilder
    private var content: some View {
        let tasks = appState.backgroundTaskSnapshots

        if tasks.isEmpty {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "terminal.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(red: 0.26, green: 0.34, blue: 0.48)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 40)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.54, green: 0.59, blue: 0.68), Color(red: 0.25, green: 0.31, blue: 0.42)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(appState.localized("No background tasks"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.23, green: 0.31, blue: 0.46))

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(tasks) { task in
                            MenuBarTaskRow(
                                task: task,
                                onOpen: { onOpenTask(task.id) },
                                onInterrupt: onInterrupt
                            )
                        }
                    }
                    .padding(14)
                }

                if appState.completedBackgroundTaskCount > 0 {
                    Divider()
                    Button(appState.localized("Clear Completed"), action: onClearCompleted)
                        .font(.system(size: 12, weight: .medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
            }
        }
    }
}

private struct MenuBarTaskRow: View {
    @EnvironmentObject private var appState: AppState

    let task: BackgroundTaskSnapshot
    let onOpen: () -> Void
    let onInterrupt: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                statusIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.command)
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                    Text("\(task.title) · \(statusText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if task.isRunning {
                    Button(appState.localized("Interrupt"), action: onInterrupt)
                        .font(.caption)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.36))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var statusIcon: some View {
        if task.isRunning {
            ProgressView()
                .scaleEffect(0.62)
                .frame(width: 22, height: 22)
        } else {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22, height: 22)
        }
    }

    private var statusText: String {
        switch task.state {
        case .running:
            return "\(appState.localized("Running")) · \(format(task.duration))"
        case .finished(let code):
            return code == 0 ? "\(appState.localized("Done")) · \(format(task.duration))" : "\(appState.localized("Exit")) \(code) · \(format(task.duration))"
        case .interrupted:
            return "\(appState.localized("Interrupted")) · \(format(task.duration))"
        }
    }

    private var iconName: String {
        switch task.state {
        case .running:
            return "timer"
        case .finished(let code):
            return code == 0 ? "checkmark.circle.fill" : "xmark.circle.fill"
        case .interrupted:
            return "stop.circle.fill"
        }
    }

    private var iconColor: Color {
        switch task.state {
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
