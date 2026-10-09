//
//  ShopItemCategory.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/09/26.
//

import SwiftUI

/// The aisle a shopping list item belongs to.
enum ShopItemCategory: String, CaseIterable, Identifiable, Codable {
    case food
    case produce
    case drinks
    case cleaning
    case hygiene
    case home
    case pets
    case other

    var id: String { rawValue }

    /// Preselected when adding an item: the first one in the picker.
    static let `default`: ShopItemCategory = .food

    /// Name shown to the user.
    var displayName: String {
        switch self {
        case .food: return L10n.tr("Alimentos")
        case .produce: return L10n.tr("Hortifruti")
        case .drinks: return L10n.tr("Bebidas")
        case .cleaning: return L10n.tr("Limpeza")
        case .hygiene: return L10n.tr("Higiene")
        case .home: return L10n.tr("Casa")
        case .pets: return L10n.tr("Pets")
        case .other: return L10n.tr("Outros")
        }
    }

    /// SF Symbol drawn on cards and chips.
    var symbol: String {
        switch self {
        case .food: return "fork.knife"
        case .produce: return "leaf"
        case .drinks: return "cup.and.saucer"
        case .cleaning: return "sparkles"
        case .hygiene: return "shower"
        case .home: return "house"
        case .pets: return "pawprint"
        case .other: return "basket"
        }
    }

    /// Reuses the rooms' palette, so cards look like the chore cards.
    var roomColor: RoomColor {
        switch self {
        case .food: return .orange
        case .produce: return .green
        case .drinks: return .purple
        case .cleaning: return .blue
        case .hygiene: return .blue
        case .home: return .yellow
        case .pets: return .green
        case .other: return .purple
        }
    }

    /// The texture drawn behind the category's icon tile. Falls back to clouds where the
    /// asset catalog has no such pattern in the category's color (see ``RoomTexturePattern``).
    var texturePattern: RoomTexturePattern {
        switch self {
        case .food, .pets: return .worms
        case .produce, .home: return .clouds
        case .drinks: return .halfCircle
        case .cleaning: return .sparkles
        case .hygiene, .other: return .stars
        }
    }

    var color: Color { roomColor.uiColor }
    var softColor: Color { roomColor.lowOpacityColor }
}
