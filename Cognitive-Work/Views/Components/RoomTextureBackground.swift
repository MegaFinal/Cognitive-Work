//
//  RoomTextureBackground.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 28/09/26.
//

import SwiftUI

/// A room card's background: the room's palette color with its texture on top.
struct RoomTextureBackground: View {
    let color: RoomColor
    let pattern: RoomTexturePattern
    
    /// The texture is always drawn at this opacity, over the room's color.
    static let textureOpacity: Double = 0.3
    
    /// How much the texture is enlarged past "fill the card" (centered, the excess is clipped).
    /// Higher means bigger, fewer shapes.
    static let textureZoom: CGFloat = 2.5
    
    init(color: RoomColor, pattern: RoomTexturePattern) {
        self.color = color
        self.pattern = pattern
    }
    
    init(room: RoomModel) {
        self.init(color: room.color, pattern: room.texturePattern)
    }
    
    var body: some View {
        color.uiColor
            .overlay {
                Image(pattern.assetName(for: color))
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(Self.textureZoom)
                    .opacity(Self.textureOpacity)
            }
            .clipped()
    }
}

#Preview {
    HStack {
        RoomTextureBackground(color: .purple, pattern: .clouds)
        RoomTextureBackground(color: .orange, pattern: .stars)
        RoomTextureBackground(color: .green, pattern: .worms)
    }
    .frame(height: 300)
    .padding()
}
