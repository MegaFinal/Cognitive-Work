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
    let chore: ChoreModel
    let namespace: Namespace.ID
    
    var carouselViewModel: CarouselViewModel
    
    var room: RoomModel? { carouselViewModel.getRoom(for: chore) }
    
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
        .foregroundColor(.white)
        .frame(width: width * 0.7, height: height * 0.43)
        .background(room?.color.uiColor ?? .gray)
        .clipShape(RoundedRectangle(cornerRadius: 31))
        .shadow(color: .black.opacity(0.14), radius: 16.84883, x: 0, y: 4.79682)
        .transition(.identity)
    }
}
