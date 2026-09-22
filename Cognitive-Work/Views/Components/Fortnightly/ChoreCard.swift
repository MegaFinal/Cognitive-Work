//
//  ChoreCard.swift
//  Cognitive-Work
//
//  Created by anshu Li on 25/08/26.
//

import SwiftUI
import CloudKit

struct ChoreCard: View {
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    let chore: ChoreModel
    let user: UserModel?
    let room: RoomModel?
    
    var body: some View {
        VStack(spacing: 30) {
            title
            
            HStack {
                Image(systemName: room?.symbol ?? "toilet")
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * 0.2)
                    .padding(.horizontal)
                
                ChorePriority(chore: chore, user: user)
            }
        }
        // A white-colored room needs black content on top of it (see
        // `RoomColor.contentColor`), otherwise the icon and title render white-on-white.
        .foregroundColor(room?.color.contentColor ?? .white)
        .frame(width: width * 0.85, height: height * 0.35)
        .background(room?.color.uiColor ?? .teal)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.32), radius: 5.8, x: 4, y: 6)
    }
    
    private var title: some View {
        VStack {
            Text(room?.name ?? "Cômodo")
                .fontWeight(.regular)
                .font(.system(size: 17, weight: .semibold))
            Text(chore.name)
                .bold()
                .font(.system(size: 28))
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
                UserProfilePictureTag(user: user, widthMultiplier: 0.08)

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
    
    ChoreCard(chore: mockChore, user: nil, room: nil)
}
