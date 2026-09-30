//
//  ChoreCard.swift
//  Cognitive-Work
//
//  Created by anshu Li on 25/08/26.
//

import SwiftUI
import CloudKit

struct ChoreCard: View {
    
    let chore: ChoreModel
    let user: UserModel?
    let room: RoomModel?
    
    var body: some View {
        VStack(spacing: 30) {
            title
            
            HStack {
                Image(systemName: room?.symbol ?? chore.symbolName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * 0.2)
                    .padding(.horizontal)
                
                ChorePriority(chore: chore, user: user)
            }
        }
        .foregroundColor(.white)
        .frame(width: width * 0.85, height: height * 0.35)
        .background(room?.color.lowOpacityColor ?? .gray)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.32), radius: 5.8, x: 4, y: 6)
    }
    
    private var title: some View {
        VStack {
            Text(room?.name ?? L10n.tr("Cômodo"))
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
    /// Was `@State`: SwiftUI keeps a `@State` value across re-renders and ignores the new one
    /// passed in by the parent, so every card kept showing the first selected user's photo.
    let user: UserModel?
    
    var body: some View {
        HStack {
            Rectangle()
                .frame(width: 2)
            
            VStack(alignment: .leading) {
                UserProfilePictureTag(user: user, widthMultiplier: 0.08)

                CapsuleTag(
                    tagName: chore.priorityTag.displayName,
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
