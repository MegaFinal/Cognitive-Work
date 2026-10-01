//
//  FortnightlyScheduleViewModel.swift
//  Cognitive-Work
//
//  Created by Carolina Sun on 28/08/26.
//

import Foundation
import SwiftUI

@Observable
@MainActor

final class ScheduleViewModel {    
    var users: [UserModel] = []
    var chores: [ChoreModel] = []
    var errorMessage: String?
    var isLoading = true
    
    /// Assignments and rooms handed in up front; `nil` means ``FortnightlyView`` fetches them.
    private(set) var assignments: [RecurrentAssignmentModel]?
    private(set) var rooms: [RoomModel]?
    
    /// Whether the data was handed in up front, in which case nothing is fetched or generated.
    private let isPreloaded: Bool
    
    init() {
        self.isPreloaded = false
    }
    
    /// Starts with data already in memory and never touches CloudKit (e.g. SwiftUI previews).
    init(
        users: [UserModel],
        chores: [ChoreModel],
        assignments: [RecurrentAssignmentModel],
        rooms: [RoomModel]
    ) {
        self.users = users
        self.chores = chores
        self.assignments = assignments
        self.rooms = rooms
        self.isLoading = false
        self.isPreloaded = true
    }
    
    private func setup() async {
        async let fetchUsers = CloudKitManager.shared.fetchHouseUsers()
        async let fetchChores = CloudKitManager.shared.fetchAll(ChoreModel.self)
        
        self.users = await fetchUsers
        self.chores = await fetchChores
    }
    
    func generateSchedule() async {
        guard !isPreloaded else { return }
        isLoading = true
        await setup()
        await resetUpcomingSchedule(for: chores)
        await TaskSchedulerEngine.schedule(chores: chores, users: users)
        isLoading = false
    }
    
    func loadSchedule(shouldGenerate: Bool) async {
        guard !isPreloaded else { return }
        isLoading = true

        if shouldGenerate {
            await setup()

            await resetUpcomingSchedule(for: chores)

            await TaskSchedulerEngine.schedule(
                chores: chores,
                users: users
            )

            // TODO: implement notification for users when its done loading?
            NotificationCenter.default.post(
                name: .cloudKitDidChange,
                object: nil
            )
        }

        await setup()
        
        isLoading = false
    }
}
