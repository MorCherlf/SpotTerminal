// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import AppKit
import ApplicationServices
import CoreGraphics

enum QuickPanelHotKey: String, CaseIterable, Identifiable {
    case doubleLeftCommand
    case controlOptionSpace
    case controlOptionReturn
    case controlOptionK

    var id: String { rawValue }

    var title: String {
        switch self {
        case .doubleLeftCommand:
            return "Double-tap Left Command"
        case .controlOptionSpace:
            return "Control + Option + Space"
        case .controlOptionReturn:
            return "Control + Option + Return"
        case .controlOptionK:
            return "Control + Option + K"
        }
    }

    var shortcutText: String {
        switch self {
        case .doubleLeftCommand:
            return "double ⌘"
        case .controlOptionSpace:
            return "⌃⌥Space"
        case .controlOptionReturn:
            return "⌃⌥Return"
        case .controlOptionK:
            return "⌃⌥K"
        }
    }

    static func from(rawValue: String) -> QuickPanelHotKey {
        QuickPanelHotKey(rawValue: rawValue) ?? .doubleLeftCommand
    }
}

final class GlobalHotKeyMonitor {
    private let onDoubleTap: () -> Void
    private let hotKeyProvider: () -> QuickPanelHotKey
    private let doubleTapThreshold: TimeInterval = 0.3
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var eventTapThread: Thread?
    private var eventTapRunLoop: CFRunLoop?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastLeftCommandDown: TimeInterval = 0
    private let stateQueue = DispatchQueue(label: "cc.griffino.spotterminal.hotkey")

    init(hotKeyProvider: @escaping () -> QuickPanelHotKey, onDoubleTap: @escaping () -> Void) {
        self.hotKeyProvider = hotKeyProvider
        self.onDoubleTap = onDoubleTap
    }

    deinit {
        stop()
    }

    func start() {
        installNSEventMonitors()
        startEventTapThread()
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource, let eventTapRunLoop {
            CFRunLoopRemoveSource(eventTapRunLoop, runLoopSource, .commonModes)
            CFRunLoopStop(eventTapRunLoop)
        }
        eventTap = nil
        runLoopSource = nil
        eventTapRunLoop = nil
        eventTapThread = nil
    }

    private func startEventTapThread() {
        guard AXIsProcessTrusted(), eventTapThread == nil else { return }

        let thread = Thread { [weak self] in
            self?.installEventTapOnCurrentThread()
        }
        thread.name = "SpotTerminal.GlobalHotKeyMonitor"
        eventTapThread = thread
        thread.start()
    }

    private func installEventTapOnCurrentThread() {
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue) | CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<GlobalHotKeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    monitor.enableEventTap()
                } else {
                    monitor.handle(type: type, keyCode: event.getIntegerValueField(.keyboardEventKeycode), flags: event.flags)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        )

        guard let tap else { return }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        let runLoop = CFRunLoopGetCurrent()

        eventTap = tap
        runLoopSource = source
        eventTapRunLoop = runLoop

        if let source {
            CFRunLoopAddSource(runLoop, source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        CFRunLoopRun()
    }

    private func installNSEventMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(event: event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(event: event)
            return event
        }
    }

    private func handle(event: NSEvent) {
        switch event.type {
        case .keyDown:
            handle(type: .keyDown, keyCode: Int64(event.keyCode), flags: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
        case .flagsChanged:
            handle(type: .flagsChanged, keyCode: Int64(event.keyCode), flags: CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)))
        default:
            break
        }
    }

    private func handle(type: CGEventType, keyCode: Int64, flags: CGEventFlags) {
        if type == .keyDown {
            let hotKey = hotKeyProvider()
            if hotKey.matchesKeyDown(keyCode: keyCode, flags: flags) {
                DispatchQueue.main.async {
                    self.onDoubleTap()
                }
                return
            }
            stateQueue.async {
                self.lastLeftCommandDown = 0
            }
            return
        }

        guard type == .flagsChanged else { return }
        let isLeftCommand = keyCode == 55
        let isCommandDown = flags.contains(.maskCommand)
        guard hotKeyProvider() == .doubleLeftCommand, isLeftCommand, isCommandDown else { return }

        let now = ProcessInfo.processInfo.systemUptime
        stateQueue.async {
            if now - self.lastLeftCommandDown <= self.doubleTapThreshold {
                self.lastLeftCommandDown = 0
                DispatchQueue.main.async {
                    self.onDoubleTap()
                }
            } else {
                self.lastLeftCommandDown = now
            }
        }
    }

    private func enableEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }
}

private extension QuickPanelHotKey {
    func matchesKeyDown(keyCode: Int64, flags: CGEventFlags) -> Bool {
        switch self {
        case .doubleLeftCommand:
            return false
        case .controlOptionSpace:
            return keyCode == 49 && flags.containsRequired([.maskControl, .maskAlternate])
        case .controlOptionReturn:
            return (keyCode == 36 || keyCode == 76) && flags.containsRequired([.maskControl, .maskAlternate])
        case .controlOptionK:
            return keyCode == 40 && flags.containsRequired([.maskControl, .maskAlternate])
        }
    }
}

private extension CGEventFlags {
    func containsRequired(_ required: [CGEventFlags]) -> Bool {
        required.allSatisfy { contains($0) }
    }
}
