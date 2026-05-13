// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import AppKit
import ApplicationServices
import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isPresented: Bool
    @Binding var didCompleteOnboarding: Bool

    @State private var accessibilityTrusted = AXIsProcessTrusted()
    @State private var notificationStatus = UNAuthorizationStatus.notDetermined
    @State private var diagnostics = SystemDiagnostics.snapshot()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    permissionsSection
                    hotKeySection
                    diagnosticsSection
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(width: 620, height: 640)
        .onAppear {
            refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.localized("Welcome to Spot Terminal"))
                .font(.title2.weight(.semibold))
            Text(appState.localized("A quick pass through permissions and shell readiness before you start."))
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appState.localized("Permissions"))
                .font(.headline)
            PermissionSetupRow(
                title: appState.localized("Accessibility"),
                detail: appState.localized("Required for global hotkeys."),
                isReady: accessibilityTrusted,
                readyText: appState.localized("Allowed"),
                actionTitle: appState.localized("Open Settings"),
                action: openAccessibilitySettings
            )
            PermissionSetupRow(
                title: appState.localized("Notifications"),
                detail: appState.localized("Used when background tasks finish."),
                isReady: notificationsAreEnabled,
                readyText: notificationStatusText,
                actionTitle: appState.localized("Request"),
                action: requestNotifications
            )
        }
    }

    private var hotKeySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appState.localized("Quick Panel Hotkey"))
                .font(.headline)
            Picker(appState.localized("Quick Panel"), selection: $appState.quickPanelHotKeyID) {
                ForEach(QuickPanelHotKey.allCases) { hotKey in
                    Text("\(appState.localized(hotKey.title)) (\(hotKey.shortcutText))")
                        .tag(hotKey.rawValue)
                }
            }
            .pickerStyle(.radioGroup)
        }
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(appState.localized("Shell Diagnostics"))
                    .font(.headline)
                Spacer()
                Button(appState.localized("Refresh")) {
                    refresh()
                }
            }
            VStack(spacing: 8) {
                ForEach(diagnostics) { item in
                    DiagnosticRow(item: item)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button(appState.localized("Open Settings")) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            Spacer()
            Button(appState.localized("Finish")) {
                didCompleteOnboarding = true
                isPresented = false
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }

    private var notificationsAreEnabled: Bool {
        notificationStatus == .authorized || notificationStatus == .provisional
    }

    private var notificationStatusText: String {
        switch notificationStatus {
        case .notDetermined:
            return appState.localized("Not requested")
        case .denied:
            return appState.localized("Denied")
        case .authorized:
            return appState.localized("Allowed")
        case .provisional:
            return appState.localized("Allowed quietly")
        case .ephemeral:
            return appState.localized("Allowed temporarily")
        @unknown default:
            return appState.localized("Unknown")
        }
    }

    private func refresh() {
        accessibilityTrusted = AXIsProcessTrusted()
        diagnostics = SystemDiagnostics.snapshot()
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
    }

    private func requestNotifications() {
        appState.taskNotifier?.requestAuthorizationIfNeeded { _ in
            refresh()
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

private struct PermissionSetupRow: View {
    let title: String
    let detail: String
    let isReady: Bool
    let readyText: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isReady ? .green : .orange)
                .font(.title3)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(isReady ? readyText : detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(actionTitle, action: action)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct DiagnosticRow: View {
    let item: DiagnosticItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Text(item.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var iconName: String {
        switch item.severity {
        case .ok:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        case .problem:
            return "xmark.octagon.fill"
        }
    }

    private var iconColor: Color {
        switch item.severity {
        case .ok:
            return .green
        case .warning:
            return .orange
        case .problem:
            return .red
        }
    }
}
