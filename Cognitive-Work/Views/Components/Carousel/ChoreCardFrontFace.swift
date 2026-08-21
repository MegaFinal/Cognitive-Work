//
//  ChoreCardFrontFace.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI

struct ChoreCardFrontFace: View {
    let viewModel: CarouselCardViewModel
    
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
        .frame(width: width * 0.68, height: height * 0.4)
        .background(viewModel.roomColor)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

#Preview {
    let mockChore = ChoreModel(name: "Lavar banheiro", description: "", frequency: .weekly, duration: 1800, isPublic: true, priorityTag: .urgent)
    let mockVM = CarouselCardViewModel.mock(chore: mockChore, roomName: "Banheiro da Suíte", color: RoomColor.blue.uiColor, imageName: "person.circle")
    
    return ChoreCardFrontFace(viewModel: mockVM)
}
