//
//  ChorePriority.swift
//  Cognitive-Work
//
//  Created by anshu Li on 25/08/26.
//

import SwiftUI

struct ChorePriority: View {
    let chore: ChoreModel
    @Binding var user: UserModel

    var body: some View {
        HStack {
            Rectangle()
                .frame(width: 2)

            VStack(alignment: .leading) {
                UserProfilePictureTag(user: $user)
                PriorityDurationTag(text: priorityText, color: .subTitleGray)
                PriorityDurationTag(text: tier.displayText, color: .titleGray)
            }
        }
        .frame(height: 100)
    }

    private var priorityText: String {
        switch chore.priorityTag {
        case .urgent: return "urgente"
        case .high: return "alta"
        case .medium: return "média"
        case .low: return "baixa"
        }
    }

    private var tier: ChoreDurationTier {
        ChoreDurationTier.from(minutes: chore.duration)
    }
}

#Preview {
    let mockImageData = UIImage(named: "defaultUser")?.pngData()
    let mockUser = UserModel(name: "Dayô", profilePicture: mockImageData, tier: .tier1)

    let mockChore = ChoreModel(
        name: "Lavar banheiro",
        description: "Limpeza completa",
        frequency: .weekly,
        duration: 50.0,
        isPublic: true,
        priorityTag: .urgent
    )

    return ChorePriority(chore: mockChore, user: .constant(mockUser))
}
