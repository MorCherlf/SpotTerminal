// Copyright 2026 MorCherlf
// SPDX-License-Identifier: Apache-2.0

import Foundation

struct CommandSuggestion: Identifiable, Equatable {
    let id: String
    var title: String
    var subtitle: String
    var sectionTitle: String
    var systemImage: String
    var kind: CommandSuggestionKind
}

enum CommandSuggestionKind: Equatable {
    case command(String)
    case archive(UUID)
}

struct ArchivedCommandMatch: Identifiable, Equatable {
    let id: String
    var command: String
    var sessionTitle: String
    var archivedAt: Date
}
