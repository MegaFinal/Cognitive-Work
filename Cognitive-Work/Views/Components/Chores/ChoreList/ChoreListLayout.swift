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
    let namespace: Namespace.ID
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                ForEach(Array(viewModel.cardModels.enumerated()), id: \.element.id) { index, chore in
                    ChoreCardListStyle(chore: chore, namespace: namespace) {
                        viewModel.focusDetailsImmediately(index)
                    }
                }
            }
            .padding(.top, 8)
        }
        .onSwipeDown(action: onSwipeDown)
        .matchedGeometryEffect(id: "Spawnpoint", in: namespace)
    }
}
