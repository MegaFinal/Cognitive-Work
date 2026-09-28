//
//  ChoreCarouselCard.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI
import CloudKit

/// The distinct front-face representation of a chore inside the carousel layout.
///
/// Focuses strictly on prominent typography and large-scale iconography over the respective room color.
struct ChoreCarouselCard: View {
    let chore: ChoreModel
    let namespace: Namespace.ID
    
    var carouselViewModel: CarouselViewModel
    
    var room: RoomModel? { carouselViewModel.getRoom(for: chore) }
    
    var body: some View {
        ZStack {
            VStack {
                Text(chore.name)
                    .font(.system(size: 26))
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .frame(width: width * 0.6)
                Spacer()
            }
            .padding(.top, 30)
            
            Image(systemName: room?.symbol ?? chore.symbolName)
                .resizable()
                .scaledToFill()
                .frame(width: width * 0.17, height: height * 0.17)
                .fontWeight(.ultraLight)
        }
        .foregroundColor(.white)
        .frame(width: width * 0.7, height: height * 0.43)
        .background { cardBackground }
        .clipShape(RoundedRectangle(cornerRadius: 31))
        .shadow(color: .black.opacity(0.14), radius: 16.84883, x: 0, y: 4.79682)
        .transition(.identity)
    }
    
    /// The room's color with its texture; gray when the chore's room is unknown.
    @ViewBuilder
    private var cardBackground: some View {
        if let room {
            RoomTextureBackground(room: room)
        } else {
            Color.gray
        }
    }
}

#Preview("Com cômodo") {
    @Previewable @Namespace var namespace

    let vm: CarouselViewModel = {
        var room = RoomModel(name: "Cozinha", symbol: "fork.knife", color: .orange)
        room.recordID = CKRecord.ID(recordName: "preview-room")

        let vm = CarouselViewModel()
        vm.roomModels = [room]
        return vm
    }()

    let chore: ChoreModel = {
        let chore = ChoreModel(
            name: "Repor papel e produtos de higiene",
            description: "Depois do jantar",
            frequency: .daily,
            duration: 20,
            isPublic: true,
            priorityTag: .medium,
            roomReference: CKRecord.Reference(
                recordID: CKRecord.ID(recordName: "preview-room"),
                action: .none
            )
        )
        chore.symbolName = "toilet"
        return chore
    }()

    ChoreCarouselCard(chore: chore, namespace: namespace, carouselViewModel: vm)
}
