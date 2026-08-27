//
//  ChoreListLayout.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import SwiftUI

struct ChoreListLayout: View {
    @Bindable var viewModel: CarouselViewModel
    let onSwipeDown: () -> Void
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                ForEach(Array(viewModel.cardViewModels.enumerated()), id: \.element.id) { index, cardVM in
                    ChoreCardListStyle(viewModel: cardVM)
                }
            }
            .padding(.top, 8)
        }
        .onSwipeDown(action: onSwipeDown)
        .transition(
            .asymmetric(
                insertion: .move(edge: .top) .combined(with: .opacity),
                removal: .move(edge: .top) .combined(with: .opacity)
            )
        )
    }
}
