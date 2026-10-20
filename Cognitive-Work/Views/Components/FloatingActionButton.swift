//
//  FloatingActionButton.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 16/10/26.
//

import SwiftUI

/// Round glass button that floats over the bottom-right corner of a tab root
struct FloatingActionButton: View {
    static let diameter: CGFloat = 70
    static let trailingInset: CGFloat = 22

    let systemImage: String
    var symbolSize: CGFloat = 28
    var foreground: Color = .white
    var tint: Color? = .black
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: symbolSize))
                .foregroundColor(foreground)
                .frame(width: Self.diameter, height: Self.diameter)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive().tint(tint), in: .circle)
    }
}

extension View {
    func floatingActionPlacement() -> some View {
        self
            .padding(.trailing, FloatingActionButton.trailingInset)
            .padding(.bottom)
    }
}

#Preview {
    HStack {
        FloatingActionButton(systemImage: "hand.tap", symbolSize: 32, foreground: .black, tint: nil) {}
        FloatingActionButton(systemImage: "plus") {}
    }
}
