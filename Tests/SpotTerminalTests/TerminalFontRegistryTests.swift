// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import AppKit
@testable import SpotTerminal
import Testing

@Suite("TerminalFontRegistry")
struct TerminalFontRegistryTests {
    @Test func bundledDefaultSupportsOhMyZshGlyphs() {
        let defaultFontName = TerminalFontRegistry.preferredDefaultFontName
        #expect(TerminalFontRegistry.fontNameSupportsTerminalSymbols(defaultFontName))
    }

    @Test func legacySystemFontMigratesToBundledNerdFont() {
        let resolved = TerminalFontRegistry.resolvedInitialFontName(stored: "Menlo-Regular")
        #expect(resolved == TerminalFontRegistry.preferredDefaultFontName)
        #expect(TerminalFontRegistry.fontNameSupportsTerminalSymbols(resolved))
    }
}
