//
//  CarouselCardViewModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI
import CloudKit

@Observable
class CarouselCardViewModel: Identifiable {
    let id = UUID()
    
    var chore: ChoreModel
    
    var isShowingBack: Bool = false
    var isLoadingDependencies: Bool = false
    
    var roomName: String = "Nome do Cômodo"
    var roomColor: Color = .gray
    var profileImage: Image? = nil
    
    var cardSymbol: String = "bus"
    
    init(chore: ChoreModel) {
        self.chore = chore
    }
    
    func flip() {
        isShowingBack.toggle()
    }
    
    func fetchRoomDependencies() async {
        guard !isLoadingDependencies else { return }
        
        await MainActor.run { isLoadingDependencies = true }
        
        if let roomRef = chore.room {

//            if let record = try? await db.record(for: roomRef.recordID),
            if let record = await CloudKitManager.shared.fetchRecord(for: <#T##CloudKitSyncable#>), predicate: <#T##NSPredicate#>),
               let room = RoomModel(record: record) {
                await MainActor.run {
                    self.roomName = room.name ?? "Nome do Cômodo"
                    self.roomColor = room.color.uiColor
                }
            }
        } else {
            await MainActor.run { self.roomName = "Cômodo não encontrado" }
        }
        
        await MainActor.run { isLoadingDependencies = false }
    }
    
    func fetchUserDependencies() async {
        guard !isLoadingDependencies else { return }
        
        await MainActor.run { isLoadingDependencies = true }
        
        await MainActor.run { isLoadingDependencies = false }
    }
    
    // MARK: - Mocks for preview
    static func mock(
        chore: ChoreModel,
        roomName: String,
        color: Color,
        imageName: String
    ) -> CarouselCardViewModel {
        let vm = CarouselCardViewModel(chore: chore)
        vm.roomName = roomName
        vm.roomColor = color
        vm.profileImage = Image(systemName: imageName)
        return vm
    }
}
