// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import AppKit
import SwiftUI

@MainActor
final class QuickPanelController {
    private let appState: AppState
    private let onExpand: () -> Void
    private var panel: NSPanel?

    init(appState: AppState, onExpand: @escaping () -> Void) {
        self.appState = appState
        self.onExpand = onExpand
    }

    func toggle() {
        if panel?.isVisible == true {
            dismiss()
        } else {
            show()
        }
    }

    func show() {
        appState.startFreshQuickSessionIfNeeded()
        PrivacySafeLogger.shared.event("quick_panel_shown")
        let panel = panel ?? makePanel()
        self.panel = panel
        position(panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        focusInput(in: panel)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func dismiss() {
        guard let panel else { return }
        PrivacySafeLogger.shared.event("quick_panel_dismissed")
        appState.closeQuickPanelSession()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.09
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func makePanel() -> NSPanel {
        let rootView = QuickPanelView(
            onDismiss: { [weak self] in
                self?.dismiss()
            },
            onExpand: { [weak self] in
                self?.onExpand()
            }
        )
        .environmentObject(appState)

        let panel = QuickPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 420),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: rootView)
        return panel
    }

    private func focusInput(in panel: NSPanel) {
        DispatchQueue.main.async {
            guard let input = panel.contentView?.firstSubview(ofType: KeyHandlingTextField.self) else {
                return
            }
            panel.makeFirstResponder(input)
            input.requestFocus()
        }
    }

    private func position(_ panel: NSPanel) {
        let screen = NSScreen.screenContainingMouse ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.maxY - visibleFrame.height * 0.24 - size.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}

private extension NSView {
    func firstSubview<T: NSView>(ofType type: T.Type) -> T? {
        if let match = self as? T {
            return match
        }
        for subview in subviews {
            if let match = subview.firstSubview(ofType: type) {
                return match
            }
        }
        return nil
    }
}

final class QuickPanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

private extension NSScreen {
    static var screenContainingMouse: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }
}
