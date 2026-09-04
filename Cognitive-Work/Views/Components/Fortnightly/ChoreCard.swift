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
    @State var roomName: String = ""

    var body: some View {
        VStack {
            title

            HStack {
                Image(systemName: "toilet")
                    .resizable()
                    .scaledToFit()
                    .frame(width: width * 0.2, height: height * 0.2)
                    .padding(.horizontal)


                ChorePriority(chore: chore)
            }
        }
        .task {
            if let room = await chore.room {
                roomName = room.name
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .foregroundStyle(.delimiteTimeSquareComponent)
                .frame(width: 345, height: 290)
        )
    }

    private var title: some View {
        VStack {
            Text(roomName)
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
                UserProfilePictureTag(imageData: user?.profilePicture?.fileURL?.dataRepresentation, widthMultiplier: 0.05)

                CapsuleTag(
                    tagName: chore.priorityTag.rawValue,
                    tagColor: .subTitleGray,
                    horizontalPadding: 0.0,
                    verticalPadding: 1.5
                )

                CapsuleTag(
                    tagName: tier.displayText,
                    tagColor: .titleGray,
                    horizontalPadding: 0.0,
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
