//
//  CarouselCardFrame.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI

/// `Frame` ensures all images fit the card's ratio
/// /// - `Parameters:`
///   - `frontFace:` View that represents the front face of the card
///   - `quantity:` View that represents the back of the card
struct CarouselCardFrame: View {
    let viewModel: ChoreViewModel
    let carouselViewModel: CarouselViewModel
    let namespace: Namespace.ID
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var isFocused: Bool = false
    var rotation: Double = 0
    var isShowingBack: Bool = false
    private let fadeDuration: Double = 0.03
    
    var body: some View {
        ZStack {
            ChoreCardFrontFace(viewModel: viewModel, namespace: namespace)
                .opacity(isShowingBack ? 0 : 1)
                .scaleEffect(
                    x: isFocused ? (0.88 / 0.72) : 1.0,
                    y: isFocused ? (0.65 / 0.47) : 1.0
                )
            
            ChoreDetails(viewModel: viewModel, carouselViewModel: carouselViewModel)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isShowingBack ? 1 : 0)
                .frame(width: 0, height: 0)
                .scaleEffect(
                    x: isFocused ? 1.0 : (0.72 / 0.88),
                    y: isFocused ? 1.0 : (0.47 / 0.65)
                )
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: isFocused)
        .animation(.easeInOut(duration: fadeDuration), value: isShowingBack)
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
    }
}

#Preview {
    @Previewable @Namespace var namespace
    let mockChore = ChoreModel(
        name: "Lavar o Banheiro",
        description: "Esfregar o chão e limpar o espelho",
        frequency: .weekly,
        duration: 1800,
        isPublic: true,
        priorityTag: .urgent
    )
    
    let mockVM = ChoreViewModel.mock(
        chore: mockChore,
        roomName: "Banheiro da Suíte",
        color: Color.blue
    )
    
    mockVM.cardSymbol = "toilet"
    
    return ChoreCardFrontFace(viewModel: mockVM, namespace: namespace)
}
