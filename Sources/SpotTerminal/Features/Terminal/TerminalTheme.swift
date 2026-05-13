// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import AppKit
import SwiftUI
import SwiftTerm

private func ansiColor(_ r: UInt16, _ g: UInt16, _ b: UInt16) -> SwiftTerm.Color {
    SwiftTerm.Color(red: r * 257, green: g * 257, blue: b * 257)
}

struct NamedTerminalTheme: Identifiable, Equatable {
    let id: String
    let displayName: String
    let ui: TerminalTheme
    let palette: ResolvedTerminalPalette

    static func == (lhs: NamedTerminalTheme, rhs: NamedTerminalTheme) -> Bool {
        lhs.id == rhs.id
    }
}

extension NamedTerminalTheme {
    static let builtIn: [NamedTerminalTheme] = [
        .defaultDark, .defaultLight, .solarizedDark, .solarizedLight, .dracula, .oneDark, .monokai, .tokyoNight
    ]

    static func resolve(id: String, colorScheme: ColorScheme) -> NamedTerminalTheme {
        if id == "system" {
            return colorScheme == .dark ? .defaultDark : .defaultLight
        }
        return builtIn.first { $0.id == id } ?? .defaultDark
    }

    static let defaultDark = NamedTerminalTheme(
        id: "default-dark",
        displayName: "Default Dark",
        ui: TerminalTheme(
            background: SwiftUI.Color(red: 0.075, green: 0.085, blue: 0.105),
            surface: SwiftUI.Color(red: 0.13, green: 0.145, blue: 0.17).opacity(0.88),
            text: SwiftUI.Color(red: 0.88, green: 0.90, blue: 0.94),
            secondaryText: SwiftUI.Color(red: 0.58, green: 0.62, blue: 0.70),
            prompt: SwiftUI.Color(red: 0.43, green: 0.70, blue: 1.0)
        ),
        palette: ResolvedTerminalPalette(
            foreground: NSColor(calibratedRed: 0.88, green: 0.90, blue: 0.94, alpha: 1),
            background: NSColor(calibratedRed: 0.075, green: 0.085, blue: 0.105, alpha: 1),
            cursor: NSColor(calibratedRed: 0.43, green: 0.70, blue: 1.0, alpha: 1),
            selection: NSColor(calibratedRed: 0.25, green: 0.35, blue: 0.55, alpha: 0.6),
            ansi: [
                ansiColor(0x2E, 0x34, 0x40),
                ansiColor(0xE0, 0x6C, 0x75),
                ansiColor(0x98, 0xC3, 0x79),
                ansiColor(0xE5, 0xC0, 0x7B),
                ansiColor(0x61, 0xAF, 0xEF),
                ansiColor(0xC6, 0x78, 0xDD),
                ansiColor(0x56, 0xB6, 0xC2),
                ansiColor(0xAB, 0xB2, 0xBF),
                ansiColor(0x5C, 0x63, 0x70),
                ansiColor(0xE0, 0x6C, 0x75),
                ansiColor(0x98, 0xC3, 0x79),
                ansiColor(0xE5, 0xC0, 0x7B),
                ansiColor(0x61, 0xAF, 0xEF),
                ansiColor(0xC6, 0x78, 0xDD),
                ansiColor(0x56, 0xB6, 0xC2),
                ansiColor(0xC8, 0xCC, 0xD4),
            ]
        )
    )

    static let defaultLight = NamedTerminalTheme(
        id: "default-light",
        displayName: "Default Light",
        ui: TerminalTheme(
            background: SwiftUI.Color(red: 0.965, green: 0.972, blue: 0.982),
            surface: SwiftUI.Color.white.opacity(0.76),
            text: SwiftUI.Color(red: 0.10, green: 0.12, blue: 0.16),
            secondaryText: SwiftUI.Color(red: 0.37, green: 0.42, blue: 0.50),
            prompt: SwiftUI.Color(red: 0.13, green: 0.34, blue: 0.72)
        ),
        palette: ResolvedTerminalPalette(
            foreground: NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.16, alpha: 1),
            background: NSColor(calibratedRed: 0.965, green: 0.972, blue: 0.982, alpha: 1),
            cursor: NSColor(calibratedRed: 0.13, green: 0.34, blue: 0.72, alpha: 1),
            selection: NSColor(calibratedRed: 0.70, green: 0.80, blue: 0.95, alpha: 0.5),
            ansi: [
                ansiColor(0x38, 0x3A, 0x42),
                ansiColor(0xE4, 0x56, 0x49),
                ansiColor(0x50, 0xA1, 0x4F),
                ansiColor(0xC1, 0x84, 0x01),
                ansiColor(0x40, 0x78, 0xF2),
                ansiColor(0xA6, 0x26, 0xA4),
                ansiColor(0x01, 0x84, 0xBC),
                ansiColor(0xA0, 0xA1, 0xA7),
                ansiColor(0x4F, 0x52, 0x5D),
                ansiColor(0xE4, 0x56, 0x49),
                ansiColor(0x50, 0xA1, 0x4F),
                ansiColor(0xC1, 0x84, 0x01),
                ansiColor(0x40, 0x78, 0xF2),
                ansiColor(0xA6, 0x26, 0xA4),
                ansiColor(0x01, 0x84, 0xBC),
                ansiColor(0x38, 0x3A, 0x42),
            ]
        )
    )

    static let solarizedDark = NamedTerminalTheme(
        id: "solarized-dark",
        displayName: "Solarized Dark",
        ui: TerminalTheme(
            background: SwiftUI.Color(red: 0.0, green: 0.169, blue: 0.212),
            surface: SwiftUI.Color(red: 0.027, green: 0.212, blue: 0.259).opacity(0.88),
            text: SwiftUI.Color(red: 0.514, green: 0.580, blue: 0.588),
            secondaryText: SwiftUI.Color(red: 0.396, green: 0.482, blue: 0.514),
            prompt: SwiftUI.Color(red: 0.149, green: 0.545, blue: 0.824)
        ),
        palette: ResolvedTerminalPalette(
            foreground: NSColor(calibratedRed: 0.514, green: 0.580, blue: 0.588, alpha: 1),
            background: NSColor(calibratedRed: 0.0, green: 0.169, blue: 0.212, alpha: 1),
            cursor: NSColor(calibratedRed: 0.514, green: 0.580, blue: 0.588, alpha: 1),
            selection: NSColor(calibratedRed: 0.027, green: 0.212, blue: 0.259, alpha: 0.7),
            ansi: [
                ansiColor(0x07, 0x36, 0x42),
                ansiColor(0xDC, 0x32, 0x2F),
                ansiColor(0x85, 0x99, 0x00),
                ansiColor(0xB5, 0x89, 0x00),
                ansiColor(0x26, 0x8B, 0xD2),
                ansiColor(0xD3, 0x36, 0x82),
                ansiColor(0x2A, 0xA1, 0x98),
                ansiColor(0xEE, 0xE8, 0xD5),
                ansiColor(0x00, 0x2B, 0x36),
                ansiColor(0xCB, 0x4B, 0x16),
                ansiColor(0x58, 0x6E, 0x75),
                ansiColor(0x65, 0x7B, 0x83),
                ansiColor(0x83, 0x94, 0x96),
                ansiColor(0x6C, 0x71, 0xC4),
                ansiColor(0x93, 0xA1, 0xA1),
                ansiColor(0xFD, 0xF6, 0xE3),
            ]
        )
    )

    static let solarizedLight = NamedTerminalTheme(
        id: "solarized-light",
        displayName: "Solarized Light",
        ui: TerminalTheme(
            background: SwiftUI.Color(red: 0.992, green: 0.965, blue: 0.890),
            surface: SwiftUI.Color(red: 0.933, green: 0.910, blue: 0.835).opacity(0.88),
            text: SwiftUI.Color(red: 0.396, green: 0.482, blue: 0.514),
            secondaryText: SwiftUI.Color(red: 0.514, green: 0.580, blue: 0.588),
            prompt: SwiftUI.Color(red: 0.149, green: 0.545, blue: 0.824)
        ),
        palette: ResolvedTerminalPalette(
            foreground: NSColor(calibratedRed: 0.396, green: 0.482, blue: 0.514, alpha: 1),
            background: NSColor(calibratedRed: 0.992, green: 0.965, blue: 0.890, alpha: 1),
            cursor: NSColor(calibratedRed: 0.396, green: 0.482, blue: 0.514, alpha: 1),
            selection: NSColor(calibratedRed: 0.933, green: 0.910, blue: 0.835, alpha: 0.7),
            ansi: [
                ansiColor(0xEE, 0xE8, 0xD5),
                ansiColor(0xDC, 0x32, 0x2F),
                ansiColor(0x85, 0x99, 0x00),
                ansiColor(0xB5, 0x89, 0x00),
                ansiColor(0x26, 0x8B, 0xD2),
                ansiColor(0xD3, 0x36, 0x82),
                ansiColor(0x2A, 0xA1, 0x98),
                ansiColor(0x07, 0x36, 0x42),
                ansiColor(0xFD, 0xF6, 0xE3),
                ansiColor(0xCB, 0x4B, 0x16),
                ansiColor(0x93, 0xA1, 0xA1),
                ansiColor(0x83, 0x94, 0x96),
                ansiColor(0x65, 0x7B, 0x83),
                ansiColor(0x6C, 0x71, 0xC4),
                ansiColor(0x58, 0x6E, 0x75),
                ansiColor(0x00, 0x2B, 0x36),
            ]
        )
    )

    static let dracula = NamedTerminalTheme(
        id: "dracula",
        displayName: "Dracula",
        ui: TerminalTheme(
            background: SwiftUI.Color(red: 0.157, green: 0.165, blue: 0.212),
            surface: SwiftUI.Color(red: 0.200, green: 0.204, blue: 0.275).opacity(0.88),
            text: SwiftUI.Color(red: 0.973, green: 0.973, blue: 0.949),
            secondaryText: SwiftUI.Color(red: 0.475, green: 0.510, blue: 0.682),
            prompt: SwiftUI.Color(red: 0.741, green: 0.576, blue: 0.976)
        ),
        palette: ResolvedTerminalPalette(
            foreground: NSColor(calibratedRed: 0.973, green: 0.973, blue: 0.949, alpha: 1),
            background: NSColor(calibratedRed: 0.157, green: 0.165, blue: 0.212, alpha: 1),
            cursor: NSColor(calibratedRed: 0.973, green: 0.973, blue: 0.949, alpha: 1),
            selection: NSColor(calibratedRed: 0.267, green: 0.278, blue: 0.353, alpha: 0.7),
            ansi: [
                ansiColor(0x21, 0x22, 0x2C),
                ansiColor(0xFF, 0x55, 0x55),
                ansiColor(0x50, 0xFA, 0x7B),
                ansiColor(0xF1, 0xFA, 0x8C),
                ansiColor(0xBD, 0x93, 0xF9),
                ansiColor(0xFF, 0x79, 0xC6),
                ansiColor(0x8B, 0xE9, 0xFD),
                ansiColor(0xF8, 0xF8, 0xF2),
                ansiColor(0x62, 0x72, 0xA4),
                ansiColor(0xFF, 0x6E, 0x6E),
                ansiColor(0x69, 0xFF, 0x94),
                ansiColor(0xFF, 0xFF, 0xA5),
                ansiColor(0xD6, 0xAC, 0xFF),
                ansiColor(0xFF, 0x92, 0xDF),
                ansiColor(0xA4, 0xFF, 0xFF),
                ansiColor(0xFF, 0xFF, 0xFF),
            ]
        )
    )

    static let oneDark = NamedTerminalTheme(
        id: "one-dark",
        displayName: "One Dark",
        ui: TerminalTheme(
            background: SwiftUI.Color(red: 0.157, green: 0.173, blue: 0.204),
            surface: SwiftUI.Color(red: 0.192, green: 0.212, blue: 0.243).opacity(0.88),
            text: SwiftUI.Color(red: 0.671, green: 0.698, blue: 0.749),
            secondaryText: SwiftUI.Color(red: 0.361, green: 0.388, blue: 0.439),
            prompt: SwiftUI.Color(red: 0.380, green: 0.686, blue: 0.937)
        ),
        palette: ResolvedTerminalPalette(
            foreground: NSColor(calibratedRed: 0.671, green: 0.698, blue: 0.749, alpha: 1),
            background: NSColor(calibratedRed: 0.157, green: 0.173, blue: 0.204, alpha: 1),
            cursor: NSColor(calibratedRed: 0.380, green: 0.686, blue: 0.937, alpha: 1),
            selection: NSColor(calibratedRed: 0.231, green: 0.263, blue: 0.322, alpha: 0.7),
            ansi: [
                ansiColor(0x3F, 0x44, 0x51),
                ansiColor(0xE0, 0x6C, 0x75),
                ansiColor(0x98, 0xC3, 0x79),
                ansiColor(0xD1, 0x9A, 0x66),
                ansiColor(0x61, 0xAF, 0xEF),
                ansiColor(0xC6, 0x78, 0xDD),
                ansiColor(0x56, 0xB6, 0xC2),
                ansiColor(0xAB, 0xB2, 0xBF),
                ansiColor(0x5C, 0x63, 0x70),
                ansiColor(0xE0, 0x6C, 0x75),
                ansiColor(0x98, 0xC3, 0x79),
                ansiColor(0xD1, 0x9A, 0x66),
                ansiColor(0x61, 0xAF, 0xEF),
                ansiColor(0xC6, 0x78, 0xDD),
                ansiColor(0x56, 0xB6, 0xC2),
                ansiColor(0xBE, 0xC5, 0xD4),
            ]
        )
    )

    static let monokai = NamedTerminalTheme(
        id: "monokai",
        displayName: "Monokai",
        ui: TerminalTheme(
            background: SwiftUI.Color(red: 0.157, green: 0.157, blue: 0.129),
            surface: SwiftUI.Color(red: 0.208, green: 0.208, blue: 0.173).opacity(0.88),
            text: SwiftUI.Color(red: 0.973, green: 0.973, blue: 0.949),
            secondaryText: SwiftUI.Color(red: 0.467, green: 0.467, blue: 0.427),
            prompt: SwiftUI.Color(red: 0.651, green: 0.886, blue: 0.180)
        ),
        palette: ResolvedTerminalPalette(
            foreground: NSColor(calibratedRed: 0.973, green: 0.973, blue: 0.949, alpha: 1),
            background: NSColor(calibratedRed: 0.157, green: 0.157, blue: 0.129, alpha: 1),
            cursor: NSColor(calibratedRed: 0.973, green: 0.973, blue: 0.949, alpha: 1),
            selection: NSColor(calibratedRed: 0.282, green: 0.282, blue: 0.231, alpha: 0.7),
            ansi: [
                ansiColor(0x27, 0x28, 0x22),
                ansiColor(0xF9, 0x26, 0x72),
                ansiColor(0xA6, 0xE2, 0x2E),
                ansiColor(0xE6, 0xDB, 0x74),
                ansiColor(0x66, 0xD9, 0xEF),
                ansiColor(0xAE, 0x81, 0xFF),
                ansiColor(0xA1, 0xEF, 0xE4),
                ansiColor(0xF8, 0xF8, 0xF2),
                ansiColor(0x75, 0x71, 0x5E),
                ansiColor(0xF9, 0x26, 0x72),
                ansiColor(0xA6, 0xE2, 0x2E),
                ansiColor(0xE6, 0xDB, 0x74),
                ansiColor(0x66, 0xD9, 0xEF),
                ansiColor(0xAE, 0x81, 0xFF),
                ansiColor(0xA1, 0xEF, 0xE4),
                ansiColor(0xF9, 0xF8, 0xF5),
            ]
        )
    )

    static let tokyoNight = NamedTerminalTheme(
        id: "tokyo-night",
        displayName: "Tokyo Night",
        ui: TerminalTheme(
            background: SwiftUI.Color(red: 0.098, green: 0.098, blue: 0.176),
            surface: SwiftUI.Color(red: 0.145, green: 0.145, blue: 0.239).opacity(0.88),
            text: SwiftUI.Color(red: 0.659, green: 0.706, blue: 0.914),
            secondaryText: SwiftUI.Color(red: 0.337, green: 0.369, blue: 0.573),
            prompt: SwiftUI.Color(red: 0.486, green: 0.761, blue: 0.984)
        ),
        palette: ResolvedTerminalPalette(
            foreground: NSColor(calibratedRed: 0.659, green: 0.706, blue: 0.914, alpha: 1),
            background: NSColor(calibratedRed: 0.098, green: 0.098, blue: 0.176, alpha: 1),
            cursor: NSColor(calibratedRed: 0.659, green: 0.706, blue: 0.914, alpha: 1),
            selection: NSColor(calibratedRed: 0.169, green: 0.188, blue: 0.329, alpha: 0.7),
            ansi: [
                ansiColor(0x41, 0x48, 0x68),
                ansiColor(0xF7, 0x76, 0x8E),
                ansiColor(0x9E, 0xCE, 0x6A),
                ansiColor(0xE0, 0xAF, 0x68),
                ansiColor(0x7A, 0xA2, 0xF7),
                ansiColor(0xBB, 0x9A, 0xF7),
                ansiColor(0x7D, 0xCF, 0xFF),
                ansiColor(0xC0, 0xCA, 0xF5),
                ansiColor(0x56, 0x5F, 0x89),
                ansiColor(0xF7, 0x76, 0x8E),
                ansiColor(0x9E, 0xCE, 0x6A),
                ansiColor(0xE0, 0xAF, 0x68),
                ansiColor(0x7A, 0xA2, 0xF7),
                ansiColor(0xBB, 0x9A, 0xF7),
                ansiColor(0x7D, 0xCF, 0xFF),
                ansiColor(0xC0, 0xCA, 0xF5),
            ]
        )
    )
}

enum TerminalThemeKind: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }
}

struct TerminalTheme: Equatable {
    var background: SwiftUI.Color
    var surface: SwiftUI.Color
    var text: SwiftUI.Color
    var secondaryText: SwiftUI.Color
    var prompt: SwiftUI.Color

    static func resolve(_ kind: TerminalThemeKind, colorScheme: ColorScheme) -> TerminalTheme {
        switch kind {
        case .system:
            return colorScheme == .dark ? .dark : .light
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    static let light = NamedTerminalTheme.defaultLight.ui
    static let dark = NamedTerminalTheme.defaultDark.ui
}

struct ResolvedTerminalPalette {
    var foreground: NSColor
    var background: NSColor
    var cursor: NSColor
    var selection: NSColor
    var ansi: [SwiftTerm.Color]

    init(foreground: NSColor, background: NSColor, cursor: NSColor, selection: NSColor = .selectedTextBackgroundColor, ansi: [SwiftTerm.Color] = []) {
        self.foreground = foreground
        self.background = background
        self.cursor = cursor
        self.selection = selection
        self.ansi = ansi
    }

    static func resolve(_ kind: TerminalThemeKind, colorScheme: ColorScheme) -> ResolvedTerminalPalette {
        switch kind {
        case .system:
            return colorScheme == .dark ? .dark : .light
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    static let light = NamedTerminalTheme.defaultLight.palette
    static let dark = NamedTerminalTheme.defaultDark.palette
}
