//
//  CarouselCardViewModel.swift
//  Cognitive-Work
//
//  Created by Dayô Araújo on 18/08/26.
//

import SwiftUI
import CloudKit

/// General-purpose view model for a single chore's display state.
///
/// Wraps one `ChoreModel` and holds the presentation state needed to render it
/// anywhere in the app — carousel card, list row, detail sheet — plus the
/// resolved display data (room name/color, responsible user's avatar)
/// fetched from CloudKit via ``fetchRoomDependencies()`` and ``fetchUserDependencies()``.
@Observable
class ChoreViewModel: Identifiable {
    let id = UUID()
    
    var chore: ChoreModel
    
    var isLoadingDependencies: Bool = false
    var hasLoadedDependencies: Bool = false
    
    var roomName: String = "Nome do Cômodo"
    var roomColor: Color = .gray
    var responsibleUsers: [UserModel] = []
    var checklistItems: [CheckItemModel] = []
    
    var cardSymbol: String = "bus"
    
    init(chore: ChoreModel) {
        self.chore = chore
    }
    
    func loadDependencies() async {
        guard !isLoadingDependencies, !hasLoadedDependencies else { return }
        await MainActor.run { isLoadingDependencies = true }
        
        async let room = fetchRoom()
        async let users = fetchResponsibleUsers()
        async let checklist = fetchChecklist()
        let (roomResult, usersResult, checklistResult) = await (room, users, checklist)
        
        await MainActor.run {
            if let roomResult {
                self.roomName = roomResult.name ?? "Cômodo não encontrado"
                self.roomColor = roomResult.color.uiColor
            } else {
                self.roomName = "Cômodo não encontrado"
            }
            self.responsibleUsers = usersResult
            self.checklistItems = checklistResult
            self.isLoadingDependencies = false
            self.hasLoadedDependencies = true
        }
    }
    
    private func fetchRoom() async -> RoomModel? {
        guard let room = chore.room else { return nil }
        return await CloudKitManager.shared
            .fetchRecordsByRecordReference(for: RoomModel.self, recordReferences: [room])?.first
    }
    
    private func fetchResponsibleUsers() async -> [UserModel] {
        guard let refs = chore.allResponsibleUsers, !refs.isEmpty else { return [] }
        return await CloudKitManager.shared
            .fetchRecordsByRecordReference(for: UserModel.self, recordReferences: refs) ?? []
    }
    
    private func fetchChecklist() async -> [CheckItemModel] {
        guard let refs = chore.checkList, !refs.isEmpty else { return [] }
        return await CloudKitManager.shared
            .fetchRecordsByRecordReference(for: CheckItemModel.self, recordReferences: refs) ?? []
    }
    
    func postpone(byDays days: Int) async {
        let currentDate = chore.dueDate ?? Date()
        
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: currentDate) {
            chore.dueDate = newDate
            
            await CloudKitManager.shared.update(chore)
        }
    }
    
    func completeChore() async {
        await MainActor.run { chore.isDone = true }
        
        await CloudKitManager.shared.update(chore)
    }
    
    static func mock(
        chore: ChoreModel,
        roomName: String,
        color: Color,
        responsibleUsers: [UserModel] = []
    ) -> ChoreViewModel {
        let vm = ChoreViewModel(chore: chore)
        vm.roomName = roomName
        vm.roomColor = color
        vm.responsibleUsers = responsibleUsers
        vm.hasLoadedDependencies = true
        return vm
    }
}
