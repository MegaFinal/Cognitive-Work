//
//  RoomTexturePattern.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/09/26.
//

import Foundation

/// The texture drawn over a room's color on its cards.
enum RoomTexturePattern: String, CaseIterable {
    case clouds
    case halfCircle
    case sparkles
    case stars
    case worms
    
    /// Used for rooms that aren't one of the default types (custom rooms).
    static let fallback: RoomTexturePattern = .sparkles
    
    /// Name of the texture image in the asset catalog for a room of `color`.
    func assetName(for color: RoomColor) -> String {
        "\(color.rawValue).\(rawValue)"
    }
}

extension DefaultRoomsOnboarding {
    
    /// Pattern of this room type (the color comes from ``color``).
    var texturePattern: RoomTexturePattern {
        switch self {
        case .bedroom: .clouds
        case .homeOffice: .worms
        case .livingRoom: .stars
        case .garage: .halfCircle
        case .kitchen: .halfCircle
        case .pantry: .sparkles
        case .bathroom: .sparkles
        case .powderRoom: .clouds
        case .laundryRoom: .stars
        case .balcony: .worms
        case .garden: .sparkles
        }
    }
}

extension RoomModel {
    
    /// Texture for this room's cards: by room type (`kind`, or the name for rooms saved before
    /// `kind` existed), falling back to ``RoomTexturePattern/fallback`` for custom rooms.
    var texturePattern: RoomTexturePattern {
        DefaultRoomsOnboarding(kind: kind, name: name)?.texturePattern ?? .fallback
    }
}

extension RoomDTO {
    
    /// Texture for this room's card on the selection screen.
    var texturePattern: RoomTexturePattern {
        DefaultRoomsOnboarding(rawValue: name)?.texturePattern ?? .fallback
    }
}
