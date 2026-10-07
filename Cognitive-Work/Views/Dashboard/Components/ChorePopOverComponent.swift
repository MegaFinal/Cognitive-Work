//
//  ChorePopOverComponent.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 05/10/26.
//

import SwiftUI
import CloudKit

struct ChorePopOverComponent: View {
    
    let chore: ChoreModel
    let user: UserModel?
    let room: RoomModel?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            title
            ChorePriority(chore: chore, user: user)
        }
        .foregroundColor(.black)
        .frame(width: width * 0.55, alignment: .leading)
        .frame(minHeight: height * 0.1)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var title: some View {
        VStack(alignment: .leading) {
            Text(room?.name.localizedDefault ?? L10n.tr("Cômodo"))
                .fontWeight(.regular)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(chore.name.localizedDefault)
                .bold()
                .font(.title2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ChorePriority: View {
    let chore: ChoreModel
    let user: UserModel?
    
    var body: some View {
        HStack() {
            CapsuleTag(
                tagName: chore.frequency.displayName,
                tagColor: chore.frequency.color,
                horizontalPadding: 7,
                verticalPadding: 1.5
            )
            
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
    
    private var tier: ChoreDurationTier {
        ChoreDurationTier.from(minutes: chore.duration)
    }
}

#Preview {
    let mockChore = ChoreModel(
        name: "Lavar banheiro",
        description: "Limpeza completa",
        frequency: .none,
        duration: 60.0,
        isPublic: true,
        priorityTag: .urgent
    )
    
    ChorePopOverComponent(chore: mockChore, user: nil, room: nil)
}
