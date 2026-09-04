//
//  ChoreCard.swift
//  Cognitive-Work
//
//  Created by anshu Li on 25/08/26.
//

import SwiftUI

struct ChoreCard: View {
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    let chore: ChoreModel
    @State var room: RoomModel? = nil
    
    var body: some View {
        VStack(spacing: 30) {
            title
            
            HStack {
                Image(systemName: "toilet")
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * 0.2)
                    .padding(.horizontal)
                
                
                ChorePriority(chore: chore)
            }
        }
        .foregroundColor(.white)
        .task {
            room = await chore.room
        }
        .frame(width: width * 0.85, height: height * 0.35)
        .background(room?.color.uiColor ?? .teal)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.32), radius: 5.8, x: 4, y: 6)
    }
    
    private var title: some View {
        VStack {
            Text(room?.name ?? "Cômodo")
                .fontWeight(.regular)
                .font(.headline)
            Text(chore.name)
                .bold()
                .font(.title)
        }
    }
}

private struct ChorePriority: View {
    let chore: ChoreModel
    @State var user: UserModel?
    
    var body: some View {
        HStack {
            Rectangle()
                .frame(width: 2)
            
            VStack(alignment: .leading) {
                UserProfilePictureTag(imageData: user?.profilePicture, widthMultiplier: 0.05)
                
                CapsuleTag(
                    tagName: chore.priorityTag.rawValue,
                    tagColor: chore.priorityTag.color,
                    horizontalPadding: 7,
                    verticalPadding: 1.5
                )
                
                CapsuleTag(
                    tagName: tier.displayText,
                    tagColor: tier.color,
                    horizontalPadding: 7,
                    verticalPadding: 1.5
                )
            }
        }
        .task {
            user = await chore.currentResponsible ?? nil
        }
        .frame(height: 100)
    }
    
    private var tier: ChoreDurationTier {
        ChoreDurationTier.from(minutes: chore.duration)
    }
}

#Preview {
    let mockChore = ChoreModel(
        name: "Lavar banheiro",
        description: "Limpeza completa",
        frequency: .weekly,
        duration: 90.0,
        isPublic: true,
        priorityTag: .urgent
    )
    
    ChoreCard(chore: mockChore)
}
