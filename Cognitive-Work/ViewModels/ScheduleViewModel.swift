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
        self.users = await CloudKitManager.shared.fetchHouseUsers()
        self.chores = await CloudKitManager.shared.fetchAll(ChoreModel.self)
    }
    
    func generateSchedule() async {
        isLoading = true
        
        await setup()

        await TaskSchedulerEngine.schedule(chores: chores,users: users)
        
        await setup()

        isLoading = false
    }
    
    //TODO: traduzir pra ingles
    /// Ponto único de entrada, chamado pela View sem ramificação própria.
    /// `shouldGenerate` indica se este dispositivo é o admin (roda o
    /// algoritmo) ou um convidado (só lê o resultado já persistido).
    func loadSchedule(shouldGenerate: Bool) async {
        isLoading = true

        if shouldGenerate {
            await setup()
            await TaskSchedulerEngine.schedule(chores: chores, users: users)
        }

        await setup()
        isLoading = false
    }
    
    
    
}
