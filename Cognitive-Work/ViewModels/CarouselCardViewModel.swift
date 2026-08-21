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
    
    func fetchRoomDependencies() async -> RoomModel? {
        guard !isLoadingDependencies else { return nil }
        
        await MainActor.run { isLoadingDependencies = true }
        
        if chore.room != nil {
            return await CloudKitManager.shared.fetchRecordsByRecordReference(for: RoomModel.self, recordReferences: [chore.room!])?.first
        } else {
            await MainActor.run { self.roomName = "Cômodo não encontrado" }
        }
        
        await MainActor.run { isLoadingDependencies = false }
        return nil
    }
    
    func fetchUserDependencies() async -> UserModel? {
        guard !isLoadingDependencies else { return nil }
        
        await MainActor.run { isLoadingDependencies = true }
        
        if chore.currentResponsible != nil {
            return await CloudKitManager.shared.fetchRecordsByRecordReference(for: UserModel.self, recordReferences: [chore.currentResponsible!])?.first
        } else {
            await MainActor.run { self.roomName = "User não encontrado" }
        }
        
        await MainActor.run { isLoadingDependencies = false }
        return nil
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
