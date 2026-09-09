//
//  DashboardModel.swift
//  Cognitive-Work
//
//  Created by Isabela Hissa Pinto on 28/08/26.
//

import Foundation
import SwiftUI
import CloudKit

@Observable
class DashboardModel: Identifiable {
    
    var users: [UserModel]
    var allChores: [ChoreModel] = []
    var averageTime: Double
    
    func setup() async {
        let fetchedChores = await CloudKitManager.shared.fetchAll(ChoreModel.self)
        let userIDs = users.compactMap { $0.recordID }
        
        self.allChores = fetchedChores.filter { chore in
            guard let responsibleID = chore.currentResponsibleReference?.recordID else { return false }
            return userIDs.contains(responsibleID)
        }
    }
    
    init(users: [UserModel], allChores: [ChoreModel], averageTime: Double) {
        self.users = users
        self.allChores = allChores
        self.averageTime = averageTime
    }
}
