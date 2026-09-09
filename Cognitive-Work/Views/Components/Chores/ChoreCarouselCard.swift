//
//  ChoreCarouselCard.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI

/// The distinct front-face representation of a chore inside the carousel layout.
///
/// Focuses strictly on prominent typography and large-scale iconography over the respective room color.
struct ChoreCarouselCard: View {
    
    /// The underlying chore data.
    let chore: ChoreModel
    
    /// The dynamically fetched room data linked to this chore.
    @State var room: RoomModel? = nil
    
    /// The namespace assigned to drive smooth morphing geometries.
    let namespace: Namespace.ID
    
    var width = UIScreen.main.bounds.width
    var height = UIScreen.main.bounds.height
    
    var body: some View {
        VStack {
            Text(chore.name)
                .font(.title)
                .fontWeight(.semibold)
            
            Image(systemName: chore.symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: width * 0.3, height: height * 0.3)
                .fontWeight(.ultraLight)
        }
        .task {
            room = await chore.room
        }
        .foregroundColor(.white)
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
