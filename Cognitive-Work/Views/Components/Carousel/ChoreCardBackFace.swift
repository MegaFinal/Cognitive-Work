//
//  ChoreCardBackFace.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI

struct ChoreCardBackFace: View {
    let viewModel: CarouselCardViewModel
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        VStack {
            Text(viewModel.roomName)
                .font(.title3)
            
            Text(viewModel.chore.name)
                .font(.title)
                .fontWeight(.medium)
            
            Image(systemName: viewModel.cardSymbol)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.25, height: height * 0.15)
            
            Group {
                if let profileImage = viewModel.profileImage {
                    profileImage
                        .resizable()
                } else {
                    Image(systemName: "person.fill")
                        .font(.caption)
                }
            }
            .scaledToFit()
            .frame(width: width * 0.05, height: height * 0.05)
        }
        .frame(width: width * 0.68, height: height * 0.4)
        .background(viewModel.roomColor)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

#Preview {
    let mockChore = ChoreModel(name: "Lavar banheiro", description: "", frequency: .weekly, duration: 1800, isPublic: true, priorityTag: .urgent)
    let mockVM = CarouselCardViewModel.mock(chore: mockChore, roomName: "Banheiro da Suíte", color: RoomColor.red.uiColor, imageName: "person.fill")
    
    return ChoreCardBackFace(viewModel: mockVM)
}
