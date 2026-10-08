//
//  DefaultChoreCatalog.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 08/10/26.
//

import Foundation

/// Tells chores that came from the app's suggestions apart from chores the user wrote.
/// > Note: once the user edits a suggested chore's description, it counts as the user's own text and
/// > stops being translated, name included.
enum DefaultChoreCatalog {
    
    /// Every suggested chore, as "name + description" keys.
    private static let entries: Set<String> = {
        var keys = Set<String>()
        for room in DefaultRoomsOnboarding.allCases {
            for chore in room.defaultChores {
                keys.insert(key(name: chore.name, description: chore.description))
            }
        }
        return keys
    }()
    
    /// Whether `name` and `description` are exactly one of the app's suggested chores.
    static func isSuggestion(name: String, description: String) -> Bool {
        entries.contains(key(name: name, description: description))
    }
    
    private static func key(name: String, description: String) -> String {
        // Unit separator: cannot appear in text typed by the user.
        "\(name)\u{1F}\(description)"
    }
}

// MARK: - Display text

extension ChoreModel {
    /// The name to display: translated only if this is a suggested chore, otherwise exactly as written.
    var localizedName: String {
        DefaultChoreCatalog.isSuggestion(name: name, description: description)
            ? name.localizedDefault
            : name
    }
    
    /// The description to display: translated only if this is a suggested chore.
    var localizedDescription: String {
        DefaultChoreCatalog.isSuggestion(name: name, description: description)
            ? description.localizedDefault
            : description
    }
}

extension ChoreDTO {
    /// The name to display: translated only if this is a suggested chore, otherwise exactly as written.
    var localizedName: String {
        DefaultChoreCatalog.isSuggestion(name: name, description: description)
            ? name.localizedDefault
            : name
    }
}
