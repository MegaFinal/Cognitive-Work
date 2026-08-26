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
    let roomName: String
    @Binding var user: UserModel

    var body: some View {
        VStack {
            ChoreCardTitle(choreName: chore.name, roomName: roomName)

            HStack {
                Image(systemName: "toilet")
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * 0.25, height: height * 0.2)
                    .padding(.horizontal)


                ChorePriority(chore: chore, user: $user)
            }
        }
    }
}

#Preview {
    let mockImageData = UIImage(named: "defaultUser")?.pngData()
    let mockUser = UserModel(name: "Dayô", profilePicture: mockImageData, tier: .tier1)

    let mockChore = ChoreModel(
        name: "Lavar banheiro",
        description: "Limpeza completa",
        frequency: .weekly,
        duration: 90.0,
        isPublic: true,
        priorityTag: .urgent
    )

    return ChoreCard(chore: mockChore, roomName: "Banheiro da suíte", user: .constant(mockUser))
}
