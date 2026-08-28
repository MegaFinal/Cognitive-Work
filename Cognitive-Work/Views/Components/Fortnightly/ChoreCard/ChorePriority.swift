//
//  ChorePriority.swift
//  Cognitive-Work
//
//  Created by anshu Li on 25/08/26.
//

import SwiftUI

struct ChorePriority: View {
    let chore: ChoreModel
    @State var user: UserModel?

    var body: some View {
        HStack {
            Rectangle()
                .frame(width: 2)

            VStack(alignment: .leading) {
                UserProfilePictureTag(imageData: user?.profilePicture)
                CapsuleTag(tagName: chore.priorityTag.rawValue, tagColor: .subTitleGray)
                CapsuleTag(tagName: tier.displayText, tagColor: .titleGray)
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
    let mockImageData = UIImage(named: "defaultUser")?.pngData()

    let mockChore = ChoreModel(
        name: "Lavar banheiro",
        description: "Limpeza completa",
        frequency: .weekly,
        duration: 50.0,
        isPublic: true,
        priorityTag: .urgent
    )

    ChorePriority(chore: mockChore)
}
