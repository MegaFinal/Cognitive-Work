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
    
    /// Enlargement of this texture; each card picks the one that fits its size.
    let zoom: CGFloat
    
    /// The texture is always drawn at this opacity, over the room's color.
    static let textureOpacity: Double = 0.2
    
    /// Higher means bigger, fewer shapes.
    static let textureZoom: CGFloat = 2.5
    
    init(color: RoomColor, pattern: RoomTexturePattern, zoom: CGFloat = textureZoom) {
        self.color = color
        self.pattern = pattern
        self.zoom = zoom
    }
    
    init(room: RoomModel, zoom: CGFloat = textureZoom) {
        self.init(color: room.color, pattern: room.texturePattern, zoom: zoom)
    }
    
    var body: some View {
        color.uiColor
            .overlay {
                Image(pattern.assetName(for: color))
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(zoom)
                    .opacity(Self.textureOpacity)
                    .allowsHitTesting(false)
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
