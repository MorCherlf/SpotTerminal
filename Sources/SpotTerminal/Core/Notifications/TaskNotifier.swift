// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation
import UserNotifications

enum TaskNotificationMode: String, CaseIterable, Identifiable {
    case all
    case failuresOnly
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .failuresOnly:
            return "Failures Only"
        case .off:
            return "Off"
        }
    }
}

final class TaskNotifier: NSObject, UNUserNotificationCenterDelegate {
    var onOpenSession: ((UUID) -> Void)?

    private let center = UNUserNotificationCenter.current()
    private var includesCommandText: Bool {
        UserDefaults.standard.object(forKey: "notificationIncludesCommandText") as? Bool ?? false
    }

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        center.getNotificationSettings { [weak self] settings in
            guard let self else {
                DispatchQueue.main.async { completion?(false) }
                return
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional:
                DispatchQueue.main.async { completion?(true) }
            case .notDetermined:
                DispatchQueue.main.async {
                    self.center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                        DispatchQueue.main.async { completion?(granted) }
                    }
                }
            case .denied, .ephemeral:
                DispatchQueue.main.async { completion?(false) }
            @unknown default:
                DispatchQueue.main.async { completion?(false) }
            }
        }
    }

    func notifyTaskFinished(sessionID: UUID, entry: CommandEntry) {
        guard shouldNotify(entry) else { return }

        requestAuthorizationIfNeeded { [weak self] granted in
            guard granted else { return }
            self?.scheduleTaskFinishedNotification(sessionID: sessionID, entry: entry)
        }
    }

    func notifyTest() {
        requestAuthorizationIfNeeded { [weak self] granted in
            guard let self, granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Spot Terminal notifications are enabled"
            content.body = "Background task notifications will appear here."
            if UserDefaults.standard.object(forKey: "notificationSoundEnabled") as? Bool ?? true {
                content.sound = .default
            }
            self.center.add(
                UNNotificationRequest(
                    identifier: "spot-terminal-test-\(UUID().uuidString)",
                    content: content,
                    trigger: nil
                )
            )
        }
    }

    private func scheduleTaskFinishedNotification(sessionID: UUID, entry: CommandEntry) {
        let content = UNMutableNotificationContent()
        content.title = title(for: entry.state)
        content.body = body(for: entry)
        if UserDefaults.standard.object(forKey: "notificationSoundEnabled") as? Bool ?? true {
            content.sound = .default
        }
        content.userInfo = ["sessionID": sessionID.uuidString]

        let request = UNNotificationRequest(
            identifier: "spot-terminal-task-\(sessionID.uuidString)-\(entry.id.uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let value = response.notification.request.content.userInfo["sessionID"] as? String,
           let id = UUID(uuidString: value) {
            DispatchQueue.main.async { [onOpenSession] in
                onOpenSession?(id)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private func title(for state: CommandRunState) -> String {
        switch state {
        case .running:
            return "Task is still running"
        case .finished(let code):
            return code == 0 ? "Background task completed" : "Background task failed"
        case .interrupted:
            return "Background task interrupted"
        }
    }

    private func body(for entry: CommandEntry) -> String {
        let command = includesCommandText ? entry.command.truncatedForNotification() : "Open Spot Terminal to view details."
        switch entry.state {
        case .running:
            return command
        case .finished(let code):
            return code == 0 ? command : "\(command) exited with code \(code)"
        case .interrupted:
            return command
        }
    }

    private func shouldNotify(_ entry: CommandEntry) -> Bool {
        let rawMode = UserDefaults.standard.string(forKey: "notificationMode") ?? TaskNotificationMode.all.rawValue
        let mode = TaskNotificationMode(rawValue: rawMode) ?? .all

        switch mode {
        case .all:
            return true
        case .failuresOnly:
            if case .finished(0) = entry.state {
                return false
            }
            return true
        case .off:
            return false
        }
    }
}

private extension String {
    func truncatedForNotification(limit: Int = 96) -> String {
        guard count > limit else { return self }
        return String(prefix(limit - 1)) + "..."
    }
}
