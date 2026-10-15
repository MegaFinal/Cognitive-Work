//
//  ProfileBanner.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 08/10/26.
//

import Foundation

/// The look of a user's profile banner: a color with a texture over it, picked from the same
/// colors and textures as the rooms (``RoomColor`` and ``RoomTexturePattern``).
struct ProfileBanner: Equatable, Hashable {
    var color: RoomColor
    var pattern: RoomTexturePattern
    
    static let `default` = ProfileBanner(color: .orange, pattern: .clouds)
    
    init(storedColor: String?, storedPattern: String?) {
        let color = RoomColor(storedValue: storedColor) ?? Self.default.color
        let pattern = storedPattern.flatMap(RoomTexturePattern.init(rawValue:)) ?? Self.default.pattern
        self.init(color: color, pattern: pattern)
    }
    
    init(color: RoomColor, pattern: RoomTexturePattern) {
        self.color = color
        self.pattern = pattern.resolved(for: color)
    }
}
