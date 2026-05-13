# Third-Party Notices

SpotTerminal is distributed under the Apache License 2.0. The app also includes or links against the following third-party components.

## SwiftTerm

- Source: https://github.com/migueldeicaza/SwiftTerm
- License: MIT
- Use: terminal emulation and terminal view rendering.

## Swift Argument Parser

- Source: https://github.com/apple/swift-argument-parser
- License: Apache License 2.0
- Use: transitive Swift package dependency currently resolved by SwiftPM.

## JetBrains Mono Nerd Font

- Source: https://github.com/ryanoasis/nerd-fonts and https://github.com/JetBrains/JetBrainsMono
- License: SIL Open Font License 1.1 for JetBrains Mono; Nerd Fonts added symbols and packaging follow the upstream Nerd Fonts license notices.
- Use: bundled monospace terminal font.

## Symbols Nerd Font

- Source: https://github.com/ryanoasis/nerd-fonts
- License: Nerd Fonts project license notices apply, including MIT-licensed symbol sources and font-specific upstream licenses where applicable.
- Use: fallback symbol glyphs for terminal prompts and icon-heavy shell themes.

## Apple Frameworks

SpotTerminal uses macOS system frameworks including AppKit, SwiftUI, ApplicationServices, CoreGraphics, UserNotifications, and OSLog. These are provided by Apple as part of the macOS SDK and are not redistributed as third-party source code in this repository.

## License Compatibility Notes

The current dependency set does not include GPL, AGPL, LGPL, or other strong copyleft dependencies. Apache-2.0, MIT, and SIL OFL are permissive or font-specific licenses and do not impose source-code copyleft requirements on SpotTerminal. Distribution should retain this notice file and the main project license.
