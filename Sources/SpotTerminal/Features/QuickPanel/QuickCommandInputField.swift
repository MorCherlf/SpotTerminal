// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import AppKit
import SwiftUI

struct QuickCommandInputField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    var placeholder: String
    var onCommit: () -> Void
    var onMoveSelection: (Int) -> Bool
    var onConfirmSuggestion: (Bool) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> KeyHandlingTextField {
        let textField = KeyHandlingTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        textField.placeholderString = placeholder
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.commit)
        textField.onCommit = onCommit
        textField.onMoveSelection = onMoveSelection
        textField.onConfirmSuggestion = onConfirmSuggestion
        context.coordinator.installMonitor(for: textField)
        return textField
    }

    func updateNSView(_ textField: KeyHandlingTextField, context: Context) {
        context.coordinator.parent = self
        textField.onCommit = onCommit
        textField.onMoveSelection = onMoveSelection
        textField.onConfirmSuggestion = onConfirmSuggestion
        textField.placeholderString = placeholder

        if textField.stringValue != text {
            textField.stringValue = text
        }

        if isFocused, textField.window?.firstResponder !== textField.currentEditor() {
            DispatchQueue.main.async {
                textField.window?.makeFirstResponder(textField)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: QuickCommandInputField
        private weak var textField: KeyHandlingTextField?
        private var keyMonitor: Any?

        init(_ parent: QuickCommandInputField) {
            self.parent = parent
        }

        @objc func commit() {
            parent.onCommit()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            parent.isFocused = false
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveDown(_:)):
                return parent.onMoveSelection(1)
            case #selector(NSResponder.moveUp(_:)):
                return parent.onMoveSelection(-1)
            case #selector(NSResponder.insertTab(_:)),
                 #selector(NSResponder.insertTabIgnoringFieldEditor(_:)):
                _ = parent.onConfirmSuggestion(true)
                return true
            case #selector(NSResponder.insertNewline(_:)):
                if parent.onConfirmSuggestion(false) {
                    return true
                }
                parent.onCommit()
                return true
            default:
                return false
            }
        }

        func installMonitor(for textField: KeyHandlingTextField) {
            self.textField = textField
            guard keyMonitor == nil else { return }
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.shouldHandle(event: event) else { return event }

                switch event.keyCode {
                case 125:
                    return self.parent.onMoveSelection(1) ? nil : event
                case 126:
                    return self.parent.onMoveSelection(-1) ? nil : event
                case 48:
                    _ = self.parent.onConfirmSuggestion(true)
                    return nil
                default:
                    return event
                }
            }
        }

        private func shouldHandle(event: NSEvent) -> Bool {
            guard let textField,
                  event.window === textField.window else {
                return false
            }

            let firstResponder = textField.window?.firstResponder
            return firstResponder === textField || firstResponder === textField.currentEditor()
        }

        deinit {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
            }
        }
    }
}

final class KeyHandlingTextField: NSTextField {
    var onCommit: (() -> Void)?
    var onMoveSelection: ((Int) -> Bool)?
    var onConfirmSuggestion: ((Bool) -> Bool)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        requestFocus()
    }

    func requestFocus() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
            self.currentEditor()?.moveToEndOfDocument(nil)
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 125:
            if onMoveSelection?(1) == true { return }
        case 126:
            if onMoveSelection?(-1) == true { return }
        case 48:
            _ = onConfirmSuggestion?(true)
            return
        case 36, 76:
            if onConfirmSuggestion?(false) == true { return }
            onCommit?()
            return
        default:
            break
        }

        super.keyDown(with: event)
    }
}
