// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

@testable import SpotTerminal
import SwiftUI
import Testing

@Suite("NamedTerminalTheme")
struct TerminalThemeTests {
    @Test func builtInThemesHaveUniqueIDs() {
        let ids = NamedTerminalTheme.builtIn.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func builtInContainsExpectedThemes() {
        let ids = Set(NamedTerminalTheme.builtIn.map(\.id))
        #expect(ids.contains("default-dark"))
        #expect(ids.contains("default-light"))
        #expect(ids.contains("dracula"))
        #expect(ids.contains("solarized-dark"))
        #expect(ids.contains("tokyo-night"))
    }

    @Test func resolveSystemDarkReturnsDefaultDark() {
        let theme = NamedTerminalTheme.resolve(id: "system", colorScheme: .dark)
        #expect(theme.id == "default-dark")
    }

    @Test func resolveSystemLightReturnsDefaultLight() {
        let theme = NamedTerminalTheme.resolve(id: "system", colorScheme: .light)
        #expect(theme.id == "default-light")
    }

    @Test func resolveUnknownIDFallsBackToDefaultDark() {
        let theme = NamedTerminalTheme.resolve(id: "nonexistent", colorScheme: .light)
        #expect(theme.id == "default-dark")
    }

    @Test func resolveExplicitThemeIgnoresColorScheme() {
        let theme = NamedTerminalTheme.resolve(id: "dracula", colorScheme: .light)
        #expect(theme.id == "dracula")
    }

    @Test func allPalettesHave16AnsiColors() {
        for theme in NamedTerminalTheme.builtIn {
            #expect(theme.palette.ansi.count == 16, "Theme \(theme.id) should have 16 ANSI colors")
        }
    }
}
