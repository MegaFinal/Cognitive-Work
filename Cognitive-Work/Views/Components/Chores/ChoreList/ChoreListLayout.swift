//
//  ChoreListLayout.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import SwiftUI

/// A vertical scroll view rendering the chores in a list format.
struct ChoreListLayout: View {
    
    /// The carousel view model controlling the global collection of chores.
    @Bindable var viewModel: CarouselViewModel
    
    /// Closure triggered to dismiss or toggle the layout context.
    let onSwipeDown: () -> Void
    
    /// Namespace required for geometric transitions into the grid view.
    let namespace: Namespace.ID
        
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                ForEach(Array((viewModel.isFilterOn ? viewModel.filteredChards : viewModel.cardModels).enumerated()), id: \.element.id) { index, chore in
                    ChoreCardListStyle(chore: chore, namespace: namespace, carouselViewModel: viewModel) {
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
