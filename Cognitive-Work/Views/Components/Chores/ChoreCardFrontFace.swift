//
//  ChoreCardFrontFace.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI

struct ChoreCardFrontFace: View {
    let viewModel: ChoreViewModel
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        VStack(spacing: 40) {
            Text(viewModel.chore.name)
                .font(.title)
            
            Image(systemName: viewModel.cardSymbol)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.3, height: height * 0.15)
        }
        .frame(width: width * 0.72, height: height * 0.47)
        .background(viewModel.roomColor)
        .clipShape(RoundedRectangle(cornerRadius: 31))
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
