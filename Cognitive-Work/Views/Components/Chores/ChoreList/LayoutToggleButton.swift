//
//  LayoutToggleButton.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 18/08/26.
//

/// A button that toggles between the grid and list card layouts.
///
/// The button observes the current layout mode from the provided
/// ``ContentViewModel`` and displays an icon representing the
/// layout that can be selected next.
///
/// Tapping the button triggers the same animated layout transition
/// used by the swipe gesture.

import SwiftUI

struct LayoutToggleButton: View {
    var viewModel: CarouselViewModel

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.55,dampingFraction: 0.78)) {
                viewModel.toggleLayout()
            }
        } label: {
            Image(systemName: viewModel.layoutMode == .grid ? "inset.filled.leftthird.middlethird.rightthird.rectangle" : "inset.filled.topthird.middlethird.bottomthird.rectangle")
            .font(.title2)
            .foregroundColor(.black)
            .padding(8)
        }
        .glassEffect(
            .regular.interactive(),
            in: .circle
        )
    }
}
