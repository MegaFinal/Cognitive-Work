//
//  ChoreCardBackFace.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI

struct ChoreCardBackFace: View {
    @Bindable var viewModel: ChoreViewModel
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        VStack(spacing: 10) {
            Text(viewModel.chore.name)
                .font(.title2)
            
            Image(systemName: viewModel.cardSymbol)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.2, height: height * 0.1)
                .fontWeight(.ultraLight)
            
            HStack {
                PriorityDurationTag(
                    text: viewModel.chore.priorityTag.rawValue,
                    color: viewModel.chore.priorityTag.color
                )
                
                PriorityDurationTag(
                    text: viewModel.chore.priorityTag.rawValue,
                    color: viewModel.chore.priorityTag.color
                )
            }
            
            VStack (alignment: .leading, spacing: 10) {
                Text(viewModel.chore.description)
                    .font(.caption)
                
                HStack {
                    Text("Cômodo")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(viewModel.roomName)
                        .font(.caption)
                        .padding(5)
                        .background(viewModel.roomColor)
                        .clipShape(Capsule())
                }
                
                Text("Checklist")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach($viewModel.checklistItems, id: \.id) { $item in
                    ChecklistItemButton(item: $item)
                }
                
                HStack {
                    Text("Responsáveis")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    ForEach($viewModel.responsibleUsers, id: \.id) { $user in
                        UserProfilePictureTag(user: $user)
                    }
                }
            }
            .frame(width: width * 0.75)
        }
        .frame(width: width * 0.88, height: height * 0.65)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 31))
        .shadow(color: .black.opacity(0.14), radius: 20.39595, x: 0, y: 5.80668)
    }
}

#Preview {
    let mockImageData = UIImage(named: "defaultUser")?.pngData()
    
    let mockChore = ChoreModel(
        name: "Lavar Banheiro",
        description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
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
    
    mockVM.checklistItems = [
        CheckItemModel(name: "Lorem ipsum dolor sit amet, consectetur adipiscing elit", isDone: true),
        CheckItemModel(name: "Lorem ipsum dolor sit amet", isDone: false),
        CheckItemModel(name: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor", isDone: false),
    ]
    
    mockVM.responsibleUsers = [
        UserModel(
            name: "Dayô",
            profilePicture: mockImageData, tier: .tier1
        )
    ]
    
    return ChoreCardBackFace(viewModel: mockVM)
}
