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
   
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height

    var rotation: Double = 0
    var isShowingBack: Bool = false
    private let fadeDuration: Double = 0.03

    var body: some View {
        ZStack {
            ChoreCardFrontFace(viewModel: viewModel)
                .opacity(isShowingBack ? 0 : 1)

            ChoreCardBackFace(viewModel: viewModel)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isShowingBack ? 1 : 0)
        }
        .animation(.easeInOut(duration: fadeDuration), value: isShowingBack)
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
    }
}

#Preview {
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
    
    return ChoreCardFrontFace(viewModel: mockVM)
}
