//
//  ChoreCardListStyle.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 26/08/26.
//

import Foundation
import SwiftUI

struct ChoreCardListStyle: View {
    @State var chore: ChoreModel
    @State var room: RoomModel? = nil
    let namespace: Namespace.ID
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        ZStack {
            FolderShape(
                cornerRadius: 25,
                tabWidth: 90,
                topCutoutHeight: 38
            )
            .fill(room?.color.uiColor ?? .gray)
            
            HStack(spacing: 35) {
                Image(systemName: chore.symbolName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * 0.1, height: height * 0.08)
                    .fontWeight(.thin)
                
                VStack(alignment: .leading) {
                    HStack {
                        PriorityDurationDotTag(
                            text: chore.priorityTag.rawValue,
                            color: chore.priorityTag.color
                        )
                        
                        PriorityDurationDotTag(
                            text: chore.priorityTag.rawValue,
                            color: chore.priorityTag.color
                        )
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text(room?.name ?? "Room not founded")
                                .font(.caption)
                            
                            Text(chore.name)
                                .font(.title2)
                                .bold()
                        }
                        
                        Spacer()
                        
                        Button {
                            Task {
                                await chore.toggle()
                            }
                        } label: {
                            Circle()
                                .frame(width: width * 0.06, height: height * 0.1)
                                .foregroundColor(chore.isDone ? .green : .white)
                        }
                    }
                }
            }
            .padding(.horizontal, 25)
            .padding(.top)
        }
        .task {
            room = await chore.room
        }
        .frame(width: width * 0.92, height: height * 0.14)
        //        .matchedGeometryEffect(id: "Spawnpoint", in: namespace)
        .transition(.identity)
    }
}

#Preview {
    @Previewable @Namespace var namespace
    let mockImageData = UIImage(named: "defaultUser")?.pngData()
    
    let mockChore = ChoreModel(
        name: "Lavar Banheiro",
        description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        frequency: .weekly,
        duration: 1800,
        isPublic: true,
        priorityTag: .urgent
    )
    
    return ChoreCardListStyle(chore: mockChore, namespace: namespace)
}
