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
    var isLoading = true
    
    private func setup() async {
        async let fetchUsers = CloudKitManager.shared.fetchHouseUsers()
        async let fetchChores = CloudKitManager.shared.fetchAll(ChoreModel.self)
        
        self.users = await fetchUsers
        self.chores = await fetchChores
    }
    
    func generateSchedule() async {
        isLoading = true
        
        await setup()
        
        await TaskSchedulerEngine.schedule(chores: chores,users: users)
        
        await setup()
        
        isLoading = false
    }
    
    func loadSchedule(shouldGenerate: Bool) async {
        isLoading = true

        if shouldGenerate {
            await setup()

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
