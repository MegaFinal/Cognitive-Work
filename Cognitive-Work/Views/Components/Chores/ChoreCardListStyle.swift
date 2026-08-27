//
//  ChoreCardListStyle.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import Foundation
import SwiftUI

struct ChoreCardListStyle: View {
    var viewModel: ChoreViewModel
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        ZStack {
            FolderShape(
                cornerRadius: 25,
                tabWidth: 90,
                topCutoutHeight: 38
            )
            .fill(viewModel.roomColor)
            
            HStack(spacing: 35) {
                Image(systemName: viewModel.cardSymbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * 0.1, height: height * 0.08)
                    .fontWeight(.thin)
                
                VStack(alignment: .leading) {
                    HStack {
                        PriorityDurationDotTag(
                            text: viewModel.chore.priorityTag.rawValue,
                            color: viewModel.chore.priorityTag.color
                        )
                        
                        PriorityDurationDotTag(
                            text: viewModel.chore.priorityTag.rawValue,
                            color: viewModel.chore.priorityTag.color
                        )
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text(viewModel.roomName)
                                .font(.caption)
                            
                            Text(viewModel.chore.name)
                                .font(.title2)
                                .bold()
                        }
                        
                        Spacer()
                        
                        Button {
                            viewModel.chore.isDone = true
                            Task {
                                await viewModel.completeChore()
                            }
                        } label: {
                            Circle()
                                .frame(width: width * 0.06, height: height * 0.1)
                                .foregroundColor(viewModel.chore.isDone ? .green : .white)
                        }
                    }
                }
            }
            .padding(.horizontal, 25)
            .padding(.top)
        }
        .frame(width: width * 0.92, height: height * 0.14)
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
    
    mockVM.cardSymbol = "sofa"
    
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
    
    return ChoreCardListStyle(viewModel: mockVM)
}
