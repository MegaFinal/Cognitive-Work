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
    @State var roomName: String = ""

    var body: some View {
        VStack {
            ChoreCardTitle(choreName: chore.name, roomName: roomName)

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
}

#Preview {
    let mockImageData = UIImage(named: "defaultUser")?.pngData()

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
