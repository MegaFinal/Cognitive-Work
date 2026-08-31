//
//  ChoreCarouselCard.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI

struct ChoreCarouselCard: View {
    let chore: ChoreModel
    @State var room: RoomModel? = nil
    let namespace: Namespace.ID
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        VStack {
            Text(chore.name)
                .font(.title)
            
            Image(systemName: chore.symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.3, height: height * 0.3)
                .fontWeight(.ultraLight)
        }
        .task {
            room = await chore.room
        }
        .frame(width: width * 0.7, height: height * 0.43)
        .background(room?.color.uiColor ?? .gray)
        .clipShape(RoundedRectangle(cornerRadius: 31))
        .shadow(color: .black.opacity(0.14), radius: 16.84883, x: 0, y: 4.79682)
        .transition(.identity)
    }
}

#Preview {
    @Previewable @Namespace var namespace
    let mockChore = ChoreModel(
        name: "Lavar o Banheiro",
        description: "Esfregar o chão e limpar o espelho",
        frequency: .weekly,
        duration: 1800,
        isPublic: true,
        priorityTag: .urgent
    )
    
    return ChoreCarouselCard(chore: mockChore, namespace: namespace)
}
